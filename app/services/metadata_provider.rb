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
    when Comic then comic
    when Movie then movie
    when Book then book
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
    directors, writers, cast = fetch_tvmaze_embedded_credits(id) if directors.blank? && writers.blank? && cast.blank?

    fields = { network: data.dig('network', 'name') || data.dig('webChannel', 'name'),
               thumbnail_url: data.dig('image', 'original') || data.dig('image', 'medium'),
               director: directors,
               writer: writers,
               actors: cast,
               genre: Array(data['genres']).join(', ').presence,
               release_year: year(data['premiered']) }
    [fields, children { json("https://api.tvmaze.com/shows/#{id}/episodes") }]
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

    fields = { network: data.dig('networks', 0, 'name'),
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
    first_issue = volume.dig('first_issue', 'id')
    if first_issue.to_s.match?(/\A\d+\z/)
      detail = optional_details do
        issue = json("https://comicvine.gamespot.com/api/issue/4000-#{first_issue}/", api_key: token, format: 'json')
        raise Unavailable unless issue['status_code'] == 1 && issue['results'].is_a?(Hash)

        [issue['results']]
      end
      credits += Array(detail.first&.fetch('person_credits', nil))
    end
    [{ publisher: volume.dig('publisher', 'name'), writer: comic_creators(credits, %w[writer]),
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

    [{ director: directors,
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

    [{ author: data['artistName'], publisher: data['sellerName'], release_year: year(data['releaseDate']),
       thumbnail_url: data['artworkUrl100']&.sub('100x100bb', '400x400bb') }, []]
  end

  def album
    return itunes(:artist) if @id.match?(/\A\d+\z/) || @id.start_with?('itunes_')

    @provider = 'MusicBrainz'
    active!('MusicBrainz')
    @id = @id.delete_prefix('musicbrainz_')
    raise Unsupported unless @id.match?(/\A[0-9a-f-]{36}\z/i)

    type = @item.external_url.to_s.include?('/release-group/') ? 'release-group' : 'release'
    data = json("https://musicbrainz.org/ws/2/#{type}/#{@id}", fmt: 'json', inc: 'artist-credits+genres')
    [{ artist: names(data['artist-credit']), genre: names(data['genres']),
       release_year: year(data['date'] || data['first-release-date']),
       thumbnail_url: "https://coverartarchive.org/#{type}/#{@id}/front-500" }, []]
  end

  def itunes(creator)
    @provider = 'iTunes'
    active!('itunes')
    data = json('https://itunes.apple.com/lookup', id: numeric_id('itunes_')).fetch('results').first
    raise Unavailable unless data.is_a?(Hash)

    [{ creator => data['artistName'], genre: data['primaryGenreName'],
       release_year: year(data['releaseDate']),
       thumbnail_url: data['artworkUrl100']&.sub('100x100bb', '600x600bb') }, []]
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
