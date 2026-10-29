# frozen_string_literal: true

require 'net/http'
require 'json'

# Fixed provider endpoints and stored identifiers only; never fetch a client-supplied URL.
class MetadataProvider
  class Unavailable < StandardError; end
  class RateLimited < StandardError; end
  class Unsupported < StandardError; end

  def initialize(item, include_children: true, deadline: nil, fresh: false, revalidate: false)
    @revalidate = revalidate
    @include_children = include_children
    @deadline = deadline
    @fresh = fresh
    @item = item
    @id = item.api_id.to_s
    @partial = false
  end

  attr_reader :partial, :provider

  def call
    raise Unsupported if @id.blank?

    case @item
    when TvShow then @id.start_with?('itunes_') ? itunes(:network) : television
    when Comic then @id.start_with?('openlibrary_') ? openlibrary : comic
    when Movie then movie
    when Book then @id.start_with?('openlibrary_') ? openlibrary : book
    when Album then album
    when VideoGame then game
    else raise Unsupported
    end
  end

  def self.image(value)
    uri = URI.parse(value.to_s)
    value if uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?
  rescue URI::InvalidURIError
    nil
  end

  private

  def json(url, query = {})
    uri = URI(url)
    uri.query = URI.encode_www_form(query) if query.any?
    JSON.parse(MediaSources::Http.cached_get(uri, deadline: @deadline, revalidate: @revalidate))
  rescue MediaSources::Http::Error => e
    raise RateLimited if e.message == 'HTTP 429'

    raise Unavailable
  end

  def key(source)
    config = ApiConfiguration.find_by(source_name: source, media_type: @item.class.name, is_active: true)
    config ||= ApiConfiguration.find_by(source_name: source, media_type: nil, is_active: true)
    raise Unavailable if config&.access_token.blank?

    config.access_token
  end

  def active!(source)
    config = ApiConfiguration.find_by(source_name: source, media_type: @item.class.name)
    raise Unavailable if config && !config.is_active
  end

  def numeric_id(prefix = '')
    value = @id.delete_prefix(prefix)
    raise Unsupported unless value.match?(/\A\d+\z/)

    value
  end

  def television
    return tmdb_television if @id.start_with?('tmdb_')

    @provider = 'TVMaze'
    active!('tvmaze')
    id = numeric_id
    data = json("https://api.tvmaze.com/shows/#{id}")
    data = {} unless data.is_a?(Hash)
    directors, writers, cast = tvmaze_credits(data['_embedded'])
    if directors.blank? && writers.blank? && cast.blank?
      embedded = optional_details { [json("https://api.tvmaze.com/shows/#{id}?embed[]=cast&embed[]=crew")] }.first
      data = data.merge('_embedded' => embedded['_embedded']) if embedded.is_a?(Hash)
      directors, writers, cast = tvmaze_credits(data['_embedded'])
    end

    fields = { metadata_credits_data: ProviderEntityMetadata.tvmaze(data),
               metadata_details: data.slice('language', 'status', 'type'),
               network: data.dig('network', 'name') || data.dig('webChannel', 'name'),
               thumbnail_url: data.dig('image', 'original') || data.dig('image', 'medium'),
               director: directors,
               writer: writers,
               actors: cast,
               genre: Array(data['genres']).join(', ').presence,
               release_year: year(data['premiered']) }
    [fields, children { json("https://api.tvmaze.com/shows/#{id}/episodes", specials: 1) }]
  end

  def tvmaze_credits(embedded)
    return [nil, nil, nil] if embedded.blank?

    cast = Array(embedded['cast']).slice(0, 10).filter_map { |c| c.dig('person', 'name') }.uniq.join(', ').presence
    crew = Array(embedded['crew'])
    directors = crew.select { |c| c['type'].to_s.downcase.include?('director') }
                    .filter_map { |c| c.dig('person', 'name') }.uniq.first(5).join(', ').presence
    writer_roles = ['creator', 'writer', 'developer', 'story', 'head writer']
    writers = crew.select { |c| writer_roles.any? { |t| c['type'].to_s.downcase.include?(t) } }
                  .filter_map { |c| c.dig('person', 'name') }.uniq.first(5).join(', ').presence
    [directors, writers, cast]
  end

  def fetch_tvmaze_embedded_credits(id)
    cast_crew = optional_details do
      embedded_data = json("https://api.tvmaze.com/shows/#{id}?embed[]=cast&embed[]=crew")
      embedded_data.is_a?(Hash) ? [embedded_data] : []
    end
    tvmaze_credits(cast_crew&.first&.dig('_embedded'))
  end

  def tmdb_television
    @provider = 'TMDB'
    active!('TMDB')
    token = key('TMDB')
    id = numeric_id('tmdb_')
    data = fetch_tmdb_show_data(id, token)
    rows = children { tmdb_tv_episodes(id, token, data['seasons']) }
    directors, writers, actors = tmdb_tv_credits(data)

    fields = { metadata_credits_data: ProviderEntityMetadata.tmdb(data),
               metadata_details: tmdb_details(data),
               network: data.dig('networks', 0, 'name'),
               thumbnail_url: data['poster_path'].present? ? "https://image.tmdb.org/t/p/w500#{data['poster_path']}" : nil,
               director: directors,
               writer: writers,
               actors: actors,
               genre: names(Array(data['genres'])),
               release_year: year(data['first_air_date']) }
    [fields, rows]
  end

  def fetch_tmdb_show_data(id, token)
    data = json("https://api.themoviedb.org/3/tv/#{id}", api_key: token, append_to_response: 'credits')
    data = json("https://api.themoviedb.org/3/tv/#{id}", api_key: token) if !data.is_a?(Hash) || data['seasons'].blank?
    data.is_a?(Hash) ? data : {}
  end

  def tmdb_tv_episodes(id, token, seasons)
    season_list = Array(seasons)
    @partial = true if season_list.length > 8
    season_list.first(8).flat_map do |season|
      json("https://api.themoviedb.org/3/tv/#{id}/season/#{season.fetch('season_number')}",
           api_key: token).fetch('episodes').map do |ep|
        still = ep['still_path']
        img = still.present? ? "https://image.tmdb.org/t/p/w500#{still}" : nil
        { 'id' => ep['id'], 'name' => ep['name'], 'season' => ep['season_number'], 'number' => ep['episode_number'],
          'airdate' => ep['air_date'], 'summary' => ep['overview'], 'image' => { 'original' => img },
          'guest_stars' => ep['guest_stars'], 'crew' => ep['crew'], 'runtime' => ep['runtime'],
          'production_code' => ep['production_code'] }
      end
    end
  end

  def tmdb_tv_credits(data)
    crew = Array(data.dig('credits', 'crew'))
    created_by = Array(data['created_by']).filter_map { |c| c['name'] }
    writing_crew = crew.select { |p| p['department'] == 'Writing' || %w[Writer Screenplay Story].include?(p['job']) }
    writers = (created_by + Array(names(writing_crew)&.split(', '))).compact_blank.uniq.first(5).join(', ').presence
    [names(crew.select { |p| p['job'] == 'Director' }), writers, names(Array(data.dig('credits', 'cast')).slice(0, 10))]
  end

  def children
    return [] unless @include_children

    rows = yield
    raise Unavailable unless rows.is_a?(Array)

    rows
  rescue Unavailable, RateLimited, JSON::ParserError, Timeout::Error, SocketError
    @partial = true
    []
  end

  def comic
    @provider = 'ComicVine'
    id = numeric_id('4050-')
    active!('ComicVine')
    token = key('ComicVine')
    data = json("https://comicvine.gamespot.com/api/volume/4050-#{id}/", api_key: token, format: 'json')
    raise Unavailable unless data['status_code'] == 1 && data['results'].is_a?(Hash)

    volume = data['results']
    rows = children { comic_pages(id, token) }
    credits = volume['person_credits'] || []
    organizations = [ProviderEntityMetadata.credit(volume['publisher'] || {}, 'Publisher', 'ComicVine',
                                                   kind: 'organization')].compact
    [{ metadata_credits_data: ProviderEntityMetadata.comic(credits) + organizations,
       publisher: volume.dig('publisher', 'name'), writer: comic_creators(credits, %w[writer]),
       artist: comic_creators(credits, %w[artist penciler inker colorist]),
       thumbnail_url: volume.dig('image', 'original_url'), external_url: volume['site_detail_url'] }, rows]
  end

  def optional_details
    yield || []
  rescue StandardError
    @partial = true
    []
  end

  def comic_creators(credits, roles)
    credits.select { |credit| credit['role'].to_s.downcase.split(/,\s*/).intersect?(roles) }
           .filter_map { |credit| credit['name'].presence }.uniq.join(', ').presence
  end

  def names(rows)
    Array(rows).filter_map { |row| row['name'].presence }.uniq.join(', ').presence
  end

  def comic_pages(id, token)
    rows = []
    # Bound each request to five pages; retain all old issues and report partial coverage.
    5.times do |page|
      data = json('https://comicvine.gamespot.com/api/issues/', api_key: token, format: 'json',
                                                                filter: "volume:#{id}", limit: 100, offset: page * 100)
      raise Unavailable unless data['status_code'] == 1 && data['results'].is_a?(Array)

      @partial = true if data['results'].any? { |row| !row['issue_number'].to_s.match?(/\A\d+\z/) }
      rows.concat(data['results'])
      return rows if rows.size >= data['number_of_total_results'].to_i || data['results'].empty?
    end
    @partial = true
    rows
  end

  def movie
    return itunes(:director) if @id.start_with?('itunes_') || @item.external_url.to_s.match?(/apple\.com|itunes\.com/)

    @provider = 'TMDB'
    active!('TMDB')
    data = json("https://api.themoviedb.org/3/movie/#{numeric_id('tmdb_')}", api_key: key('TMDB'),
                                                                             append_to_response: 'credits')
    crew = Array(data.dig('credits', 'crew'))
    cast = Array(data.dig('credits', 'cast'))
    directors = names(crew.select { |person| person['job'] == 'Director' })
    writing_crew = crew.select do |person|
      person['department'] == 'Writing' || %w[Writer Screenplay Story Author].include?(person['job'])
    end
    writers = names(writing_crew.first(5))
    actors = names(cast.slice(0, 10))
    genres = names(Array(data['genres']))

    [{ metadata_credits_data: ProviderEntityMetadata.tmdb(data),
       metadata_details: tmdb_details(data),
       director: directors,
       writer: writers,
       actors: actors,
       genre: genres,
       release_year: year(data['release_date']),
       thumbnail_url: data['poster_path'].present? ? "https://image.tmdb.org/t/p/w500#{data['poster_path']}" : nil }, []]
  end

  def book
    @provider = 'iTunes'
    active!('itunes')
    data = json('https://itunes.apple.com/lookup', id: numeric_id('itunes_')).fetch('results').first
    raise Unavailable unless data.is_a?(Hash)

    [{ metadata_credits_data: itunes_credits(data, :author),
       metadata_details: data.slice('language', 'description'),
       author: data['artistName'], publisher: data['sellerName'], release_year: year(data['releaseDate']),
       thumbnail_url: data['artworkUrl100']&.sub('100x100bb', '400x400bb') }, []]
  end

  def album
    return itunes_album if @id.match?(/\A\d+\z/) || @id.start_with?('itunes_')

    @provider = 'MusicBrainz'
    active!('MusicBrainz')
    @id = @id.delete_prefix('musicbrainz_')
    raise Unsupported unless @id.match?(/\A[0-9a-f-]{36}\z/i)

    type = @item.external_url.to_s.include?('/release-group/') ? 'release-group' : 'release'
    inc = type == 'release-group' ? 'artist-credits+genres+releases' : musicbrainz_includes
    data = json("https://musicbrainz.org/ws/2/#{type}/#{@id}", fmt: 'json', inc: inc)
    track_data = musicbrainz_track_data(data, type)
    labels = Array(track_data['label-info']).filter_map do |entry|
      ProviderEntityMetadata.credit(entry['label'] || {}, 'Label', 'MusicBrainz', kind: 'organization')
    end
    fields = { artist: names(data['artist-credit']), genre: names(data['genres']),
               metadata_credits_data: ProviderEntityMetadata.musicbrainz(data, 'Album artist') + labels,
               metadata_details: data.slice('primary-type', 'secondary-types', 'disambiguation'),
               release_year: year(data['date'] || data['first-release-date']),
               thumbnail_url: "https://coverartarchive.org/#{type}/#{@id}/front-500" }
    [fields, @include_children ? AlbumMetadata.musicbrainz(track_data) : []]
  end

  def musicbrainz_track_data(data, type)
    return data unless @include_children && type == 'release-group'

    release = Array(data['releases']).first
    return data unless release

    # MusicBrainz allows one request per second; the extra release call is refresh-only.
    sleep 1.05
    optional_details do
      [json("https://musicbrainz.org/ws/2/release/#{release.fetch('id')}", fmt: 'json', inc: musicbrainz_includes)]
    end.first || {}
  end

  def musicbrainz_includes
    'artist-credits+genres+recordings+artist-rels+recording-rels+work-rels+work-level-rels+isrcs+labels'
  end

  def itunes_album
    @provider = 'iTunes'
    active!('itunes')
    query = { id: numeric_id('itunes_') }
    if @include_children
      query[:entity] = 'song'
      query[:limit] = 200
    end
    data = json('https://itunes.apple.com/lookup', query).fetch('results')
    album = data.find { |row| row['wrapperType'] == 'collection' } || data.first
    raise Unavailable unless album.is_a?(Hash)

    credits = [ProviderEntityMetadata.credit({ 'name' => album['artistName'], 'id' => album['artistId'] },
                                             'Album artist', 'iTunes', kind: 'artist')].compact
    fields = { artist: album['artistName'], genre: album['primaryGenreName'],
               release_year: year(album['releaseDate']), metadata_credits_data: credits,
               metadata_details: album.slice('collectionExplicitness', 'copyright', 'trackCount', 'releaseDate'),
               thumbnail_url: album['artworkUrl100']&.sub('100x100bb', '600x600bb') }
    extracted_tracks = @include_children ? AlbumMetadata.itunes(data) : []
    declared_count = album['trackCount'].to_i
    @partial = true if declared_count.positive? && extracted_tracks.size < declared_count
    [fields, extracted_tracks]
  end

  def tmdb_details(data)
    { 'Original title' => data['original_title'] || data['original_name'],
      'Languages' => names(data['spoken_languages']), 'Countries' => names(data['production_countries']),
      'Runtime' => data['runtime'], 'Overview' => data['overview'], 'IMDb ID' => data['imdb_id'] }.compact_blank
  end

  def openlibrary
    @provider = 'OpenLibrary'
    active!('OpenLibrary')
    path = @id.delete_prefix('openlibrary_')
    raise Unsupported unless path.match?(%r{\A/(?:works|books)/OL\d+[WM]\z})

    data = json("https://openlibrary.org#{path}.json")
    authors = openlibrary_authors(data)
    edition = data
    if path.include?('/works/')
      edition = optional_details { json("https://openlibrary.org#{path}/editions.json", limit: 1)['entries'] }.first || {}
    end
    contributors = Array(edition['contributors']).filter_map do |entry|
      ProviderEntityMetadata.credit(entry, entry['role'].presence || 'Contributor', 'OpenLibrary')
    end
    publishers = Array(edition['publishers']).filter_map do |name|
      ProviderEntityMetadata.credit({ 'name' => name }, 'Publisher', 'OpenLibrary', kind: 'organization')
    end
    fields = { metadata_credits_data: authors + contributors + publishers,
               metadata_details: openlibrary_details(data, edition),
               author: names(authors), publisher: Array(edition['publishers']).join(', ').presence }
    [fields, []]
  end

  def openlibrary_details(data, edition)
    fields = edition.slice('isbn_10', 'isbn_13', 'number_of_pages', 'edition_name', 'publish_date')
    fields['subjects'] = Array(data['subjects']).first(20)
    fields['languages'] = Array(edition['languages']).filter_map do |language|
      language['key']&.delete_prefix('/languages/')
    end
    fields.compact_blank
  end

  def openlibrary_authors(data)
    Array(data['authors']).first(10).filter_map do |entry|
      author = entry['author'] || entry
      author_path = author['key']
      next unless author_path.to_s.match?(%r{\A/authors/OL\d+A\z})

      info = optional_details { [json("https://openlibrary.org#{author_path}.json")] }.first || {}
      ProviderEntityMetadata.credit(info, entry['type'] == 'translator' ? 'Translator' : 'Author', 'OpenLibrary',
                                    id: author_path)
    end
  end

  def itunes(creator)
    @provider = 'iTunes'
    active!('itunes')
    data = json('https://itunes.apple.com/lookup', id: numeric_id('itunes_')).fetch('results').first
    raise Unavailable unless data.is_a?(Hash)

    [{ metadata_credits_data: itunes_credits(data, creator),
       creator => data['artistName'], genre: data['primaryGenreName'],
       release_year: year(data['releaseDate']),
       thumbnail_url: data['artworkUrl100']&.sub('100x100bb', '600x600bb') }, []]
  end

  def itunes_credits(data, creator)
    role = { author: 'Author', director: 'Director', network: 'Network', artist: 'Album artist' }.fetch(creator)
    kind = creator == :network ? 'organization' : 'person'
    [ProviderEntityMetadata.credit({ 'name' => data['artistName'], 'id' => data['artistId'] },
                                   role, 'iTunes', kind: kind)].compact
  end

  def game
    adapter = if @id.start_with?('rawg_')
                GameProviders::Rawg.new(deadline: @deadline,
                                        fresh: @fresh)
              else
                GameProviders::Steam.new(
                  deadline: @deadline, fresh: @fresh
                )
              end
    @provider = adapter.name
    prefix = @provider == 'RAWG' ? 'rawg_' : 'steam_'
    [adapter.details(numeric_id(prefix)), []]
  rescue GameProviders::Base::RateLimited
    raise RateLimited
  rescue GameProviders::Base::Unavailable
    raise Unavailable
  end

  def year(value)
    match = value.to_s.match(/\A(19\d{2}|20\d{2})/)
    match[1].to_i if match
  end
end
