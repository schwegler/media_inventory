# frozen_string_literal: true

require 'net/http'
require 'json'

# Fixed provider endpoints and stored identifiers only; never fetch a client-supplied URL.
class MetadataProvider
  class Unavailable < StandardError; end
  class RateLimited < StandardError; end
  class Unsupported < StandardError; end

  def initialize(item, include_children: true, deadline: nil, fresh: false)
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
    JSON.parse(MediaSources::Http.get(uri, deadline: @deadline))
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
    fields = { network: data.dig('network', 'name') || data.dig('webChannel', 'name'),
               thumbnail_url: data.dig('image', 'original') || data.dig('image', 'medium') }
    [fields, children { json("https://api.tvmaze.com/shows/#{id}/episodes") }]
  end

  def tmdb_television
    @provider = 'TMDB'
    active!('TMDB')
    token = key('TMDB')
    id = numeric_id('tmdb_')
    data = json("https://api.themoviedb.org/3/tv/#{id}", api_key: token)
    rows = children do
      seasons = data.fetch('seasons')
      @partial = true if seasons.length > 8
      seasons.first(8).flat_map do |season|
        json("https://api.themoviedb.org/3/tv/#{id}/season/#{season.fetch('season_number')}",
             api_key: token).fetch('episodes').map do |ep|
          { 'name' => ep['name'], 'season' => ep['season_number'], 'number' => ep['episode_number'],
            'airdate' => ep['air_date'], 'summary' => ep['overview'],
            'image' => { 'original' => ep['still_path'].present? ? "https://image.tmdb.org/t/p/w500#{ep['still_path']}" : nil } }
        end
      end
    end
    [{ network: data.dig('networks', 0, 'name'),
       thumbnail_url: data['poster_path'].present? ? "https://image.tmdb.org/t/p/w500#{data['poster_path']}" : nil }, rows]
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
    yield
  rescue Unavailable, RateLimited, JSON::ParserError, Timeout::Error, SocketError
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
    [{ director: names(Array(data.dig('credits', 'crew')).select { |person| person['job'] == 'Director' }),
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

    [{ creator => data['artistName'], genre: @item.is_a?(Album) ? data['primaryGenreName'] : nil,
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
