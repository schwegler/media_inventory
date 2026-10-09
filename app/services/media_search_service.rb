# frozen_string_literal: true

require 'net/http'
require 'json'

# rubocop:disable Metrics/ClassLength
class MediaSearchService
  def self.call(query, type)
    new(query, type).call
  end

  def initialize(query, type)
    @query = query.to_s.strip.first(200)
    @type = type
  end

  def call
    return [] if @query.blank?

    return [] unless SOURCES.key?(@type)

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @deadline = started_at + 12
    @enrichment_deadline = started_at + 20
    MediaSources::Registry::CACHE.fetch(
      ['media-search-v5', @type, @query.downcase.strip,
       ApiConfiguration.order(:id).pluck(:source_name, :media_type, :is_active, :updated_at)], expires_in: 15.minutes
    ) do
      results = (SOURCES.fetch(@type) + [['InternetArchive', :fetch_internet_archive]]).flat_map do |source, method|
        next [] unless MediaSources::Registry.enabled?(source, @type.camelize)

        send(method, @query).map { |result| result.merge(source: source) }
      end
      results = ComicSearchQuery.new(@query).rank(results).first(20) if @type == 'comic'
      @deadline = @enrichment_deadline
      filter_unique_results(results.map { |result| enrich_result(result) }).first(20)
    end
  end

  SOURCES = {
    'movie' => [['TMDB', :fetch_tmdb_movies], ['itunes', :fetch_itunes_movies], ['Wikipedia', :fetch_wikipedia]],
    'tv_show' => [['tvmaze', :fetch_tvmaze_tv_shows], ['TMDB', :fetch_tmdb_tv_shows], ['itunes', :fetch_itunes_tv],
                  ['Wikipedia', :fetch_wikipedia]],
    'album' => [['itunes', :fetch_itunes_albums], ['MusicBrainz', :fetch_musicbrainz_albums],
                ['Wikipedia', :fetch_wikipedia]],
    'video_game' => [['Steam', :fetch_steam_video_games], ['RAWG', :fetch_rawg_video_games],
                     ['Wikipedia', :fetch_wikipedia]],
    'comic' => [['ComicVine', :fetch_comicvine_comics], ['OpenLibrary', :fetch_open_library],
                ['Wikipedia', :fetch_wikipedia]],
    'book' => [['OpenLibrary', :fetch_open_library], ['itunes', :fetch_itunes_books], ['Wikipedia', :fetch_wikipedia]]
  }.freeze

  private

  def enrich_result(result)
    return result if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= @deadline
    return result unless %w[TMDB ComicVine RAWG Steam MusicBrainz].include?(result[:source])

    item = @type.camelize.constantize.new
    result.each { |field, value| item.public_send("#{field}=", value) if item.has_attribute?(field) }
    fields, = MetadataProvider.new(item, include_children: false, deadline: @deadline).call
    result.merge(fields.compact_blank) { |_field, original, detail| original.presence || detail }
  rescue MetadataProvider::Unavailable, MetadataProvider::RateLimited, MetadataProvider::Unsupported,
         JSON::ParserError, Timeout::Error, SocketError, KeyError
    result
  end

  def filter_unique_results(all_results)
    seen = {}
    all_results.select do |item|
      next false if item[:title].blank?

      key = "#{item[:title].to_s.downcase.strip}_#{item[:release_year]}"

      if seen[key]
        item.except(:api_id, :external_url, :source).each do |field, value|
          seen[key][field] = value if seen[key][field].blank? && value.present?
        end
        false
      else
        seen[key] = item
      end
    end
  end

  # --- Movies ---

  def fetch_tmdb_movies(query)
    api_key = MediaSources::Registry.token('TMDB', @type.camelize)
    return [] if api_key.blank?

    url = URI("https://api.themoviedb.org/3/search/movie?api_key=#{api_key}&query=#{CGI.escape(query)}")
    response = MediaSources::Http.get(url, deadline: @deadline)
    data = JSON.parse(response)

    return [] unless data['results']

    results = data['results'].slice(0, 5).map do |item|
      director = '' # Details are fetched only after selection.
      {
        title: item['title'],
        director: director,
        release_year: item['release_date']&.split('-')&.first,
        thumbnail_url: item['poster_path'] ? "https://image.tmdb.org/t/p/w500#{item['poster_path']}" : nil,
        api_id: item['id'].to_s,
        external_url: "https://www.themoviedb.org/movie/#{item['id']}",
        is_local: false
      }
    end
    results.select { |r| r[:thumbnail_url] }
  rescue StandardError => e
    Rails.logger.error "TMDB Movie search failed: #{e.class}"
    []
  end

  def fetch_itunes_movies(query)
    url = URI("https://itunes.apple.com/search?term=#{CGI.escape(query)}&entity=movie&limit=5&country=US")
    response = MediaSources::Http.get(url, deadline: @deadline)
    data = JSON.parse(response)

    return [] unless data['results']

    results = data['results'].map do |item|
      {
        title: item['trackName'],
        director: item['artistName'],
        release_year: item['releaseDate']&.split('-')&.first,
        thumbnail_url: item['artworkUrl100']&.sub('100x100bb', '400x400bb'),
        api_id: "itunes_#{item['trackId']}",
        external_url: item['trackViewUrl'],
        is_local: false
      }
    end
    results.select { |r| r[:thumbnail_url] }
  rescue StandardError => e
    Rails.logger.error "iTunes Movie search failed: #{e.class}"
    []
  end

  # --- Albums ---

  def fetch_itunes_albums(query)
    url = URI("https://itunes.apple.com/search?term=#{CGI.escape(query)}&media=music&entity=album&limit=5&country=US")
    response = MediaSources::Http.get(url, deadline: @deadline)
    data = JSON.parse(response)

    return [] unless data['results']

    results = data['results'].map do |item|
      {
        title: item['collectionName'],
        artist: item['artistName'],
        genre: item['primaryGenreName'],
        release_year: item['releaseDate']&.split('-')&.first,
        thumbnail_url: item['artworkUrl100']&.sub('100x100bb', '500x500bb'),
        api_id: "itunes_#{item['collectionId']}",
        external_url: item['collectionViewUrl'],
        is_local: false
      }
    end
    results.select { |r| r[:thumbnail_url] }
  rescue StandardError => e
    Rails.logger.error "iTunes Album search failed: #{e.class}"
    []
  end

  def fetch_musicbrainz_albums(query)
    url = URI("https://musicbrainz.org/ws/2/release-group?query=#{CGI.escape(query)}&fmt=json")
    res = MediaSources::Http.get(url, deadline: @deadline)
    data = JSON.parse(res)

    return [] unless data['release-groups']

    data['release-groups'].slice(0, 5).map do |item|
      artist_name = item.dig('artist-credit', 0, 'name') || ''
      {
        title: item['title'],
        artist: artist_name,
        genre: item.dig('tags', 0, 'name') || '',
        release_year: item['first-release-date']&.split('-')&.first,
        thumbnail_url: "https://coverartarchive.org/release-group/#{item['id']}/front-250",
        api_id: "musicbrainz_#{item['id']}",
        external_url: "https://musicbrainz.org/release-group/#{item['id']}",
        is_local: false
      }
    end
  rescue StandardError => e
    Rails.logger.error "MusicBrainz Album search failed: #{e.class}"
    []
  end
  # --- Comics ---

  def fetch_comicvine_comics(query)
    api_key = MediaSources::Registry.token('ComicVine', 'Comic')
    return [] if api_key.blank?

    search = ComicSearchQuery.new(query)
    results = []
    offset = 0
    loop do
      url = build_comicvine_url(query, api_key, offset: offset)
      data = JSON.parse(MediaSources::Http.get(url, deadline: @deadline))
      page = parse_comicvine_results(data)
      results.concat(page)
      break unless search.year && page.any?

      offset += page.size
      total = data['number_of_total_results'].to_i
      break if total.zero? || offset >= total
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= @deadline
    end
    results
  rescue StandardError => e
    Rails.logger.error "ComicVine search failed: #{e.class}"
    results || []
  end

  def build_comicvine_url(query, api_key, offset: 0)
    search = ComicSearchQuery.new(query)
    url = URI("https://comicvine.gamespot.com/api/#{search.year ? 'volumes' : 'search'}/")
    params = { api_key: api_key, format: 'json', limit: 100,
               field_list: 'id,name,start_year,publisher,image,site_detail_url,count_of_issues' }
    if search.year
      # ComicVine ignores start_year filters; filter the returned years locally.
      params[:filter] = "name:#{search.title.tr(':,', ' ')}"
      params[:sort] = 'date_added:desc'
      params[:offset] = offset if offset.positive?
    else
      params.merge!(query: search.title, resources: 'volume')
    end
    url.query = URI.encode_www_form(params)
    url
  end

  def parse_comicvine_results(data)
    return [] unless data && data['results']

    data['results'].map do |item|
      {
        title: item['name'],
        publisher: item.dig('publisher', 'name'),
        release_year: item['start_year'],
        issue_count: item['count_of_issues'],
        thumbnail_url: item.dig('image', 'original_url') || item.dig('image', 'medium_url'),
        api_id: item['id']&.to_s,
        external_url: item['site_detail_url'],
        is_local: false
      }
    end
  end

  # --- TV Shows ---

  def fetch_tmdb_tv_shows(query)
    api_key = MediaSources::Registry.token('TMDB', @type.camelize)
    return [] if api_key.blank?

    url = URI("https://api.themoviedb.org/3/search/tv?api_key=#{api_key}&query=#{CGI.escape(query)}")
    response = MediaSources::Http.get(url, deadline: @deadline)
    data = JSON.parse(response)

    return [] unless data['results']

    results = data['results'].slice(0, 5).map do |item|
      {
        title: item['name'],
        network: '',
        release_year: item['first_air_date']&.split('-')&.first,
        thumbnail_url: item['poster_path'] ? "https://image.tmdb.org/t/p/w500#{item['poster_path']}" : nil,
        api_id: "tmdb_#{item['id']}",
        external_url: "https://www.themoviedb.org/tv/#{item['id']}",
        is_local: false
      }
    end
    results.select { |r| r[:thumbnail_url] }
  rescue StandardError => e
    Rails.logger.error "TMDB TV search failed: #{e.class}"
    []
  end

  def fetch_tvmaze_tv_shows(query)
    url = URI("https://api.tvmaze.com/search/shows?q=#{CGI.escape(query)}")
    response = MediaSources::Http.get(url, deadline: @deadline)
    data = JSON.parse(response)

    results = data.slice(0, 5).map do |item|
      map_tvmaze_show(item['show'])
    end
    results.select { |r| r[:thumbnail_url] }
  rescue StandardError => e
    Rails.logger.error "TVMaze search failed: #{e.class}"
    []
  end

  def map_tvmaze_show(show)
    network_name = if show['network']
                     show['network']['name']
                   elsif show['webChannel']
                     show['webChannel']['name']
                   end

    {
      title: show['name'],
      network: network_name,
      release_year: show['premiered']&.split('-')&.first,
      thumbnail_url: show['image'] ? (show['image']['original'] || show['image']['medium']) : nil,
      api_id: show['id'].to_s,
      external_url: show['officialSite'] || show['url'],
      is_local: false
    }
  end

  # --- Video Games ---

  def fetch_steam_video_games(query)
    uri = URI('https://store.steampowered.com/api/storesearch/')
    uri.query = URI.encode_www_form(term: query, l: 'english', cc: 'US')
    data = JSON.parse(MediaSources::Http.get(uri, deadline: @deadline))
    Array(data['items']).first(5).map do |item|
      {
        title: item['name'],
        platform: (item['platforms'] || {}).select { |_key, supported| supported }.keys.join(', '),
        thumbnail_url: item['tiny_image'],
        api_id: "steam_#{item['id']}",
        external_url: "https://store.steampowered.com/app/#{item['id']}",
        is_local: false
      }
    end
  rescue StandardError => e
    Rails.logger.warn "Steam search failed: #{e.class}"
    []
  end

  def fetch_rawg_video_games(query)
    api_key = MediaSources::Registry.token('RAWG', 'VideoGame')
    return [] if api_key.blank?

    url = URI("https://api.rawg.io/api/games?search=#{CGI.escape(query)}&key=#{api_key}")
    response = MediaSources::Http.get(url, deadline: @deadline)
    data = JSON.parse(response)

    return [] unless data['results']

    results = data['results'].slice(0, 5).map do |item|
      {
        title: item['name'],
        developer: '',
        publisher: '',
        platform: item['platforms']&.map { |p| p.dig('platform', 'name') }&.join(', '),
        release_year: item['released']&.split('-')&.first,
        thumbnail_url: item['background_image'],
        api_id: "rawg_#{item['id']}",
        external_url: "https://rawg.io/games/#{item['slug']}",
        is_local: false
      }
    end
    results.select { |r| r[:thumbnail_url] }
  rescue StandardError => e
    Rails.logger.error "RAWG search failed: #{e.class}"
    []
  end

  def fetch_wikipedia(query)
    category = { 'movie' => 'film', 'tv_show' => 'television series', 'album' => 'album',
                 'comic' => 'comic', 'video_game' => 'video game', 'book' => 'book' }.fetch(@type)
    uri = URI('https://en.wikipedia.org/w/api.php')
    uri.query = URI.encode_www_form(action: 'query', generator: 'search', gsrsearch: "#{query} #{category}",
                                    gsrlimit: 3, prop: 'pageimages|info', piprop: 'thumbnail',
                                    pithumbsize: 500, pilicense: 'any',
                                    inprop: 'url', format: 'json')
    data = JSON.parse(MediaSources::Http.get(uri, deadline: @deadline))
    (data.dig('query', 'pages') || {}).values.sort_by { |page| page['index'].to_i }.filter_map do |page|
      next unless page.dig('thumbnail', 'source')

      { title: page['title'].sub(/\s*\([^)]*\)$/, ''), thumbnail_url: page.dig('thumbnail', 'source'),
        api_id: "wiki_#{page['pageid']}", external_url: page['fullurl'], is_local: false }
    end
  rescue StandardError => e
    Rails.logger.warn "Wikipedia search failed: #{e.class}"
    []
  end

  def fetch_internet_archive(query)
    filter = {
      'movie' => 'mediatype:movies AND collection:feature_films',
      'tv_show' => 'mediatype:movies AND collection:classic_tv',
      'album' => 'mediatype:audio AND (subject:album OR collection:netlabels)',
      'video_game' => 'mediatype:software AND (subject:"video games" OR collection:softwarelibrary)',
      'book' => 'mediatype:texts',
      'comic' => 'mediatype:texts AND (subject:comics OR subject:"comic books")'
    }.fetch(@type)
    # Escape Lucene special characters rather than interpreting user input as operators.
    phrase = query.gsub(/[^[:alnum:]\s]/, ' ')
    uri = URI('https://archive.org/advancedsearch.php')
    uri.query = URI.encode_www_form(q: "title:(#{phrase}) AND (#{filter})", rows: 5, output: 'json',
                                    'fl[]' => %w[identifier title creator date publisher], 'sort[]' => 'downloads desc')
    data = JSON.parse(MediaSources::Http.get(uri, deadline: @deadline))
    Array(data.dig('response', 'docs')).filter_map do |record|
      id = record['identifier']
      next unless id.to_s.match?(/\A[a-zA-Z0-9_.-]+\z/)

      archive_result(record, id)
    end
  rescue StandardError => e
    Rails.logger.warn "Internet Archive search failed: #{e.class}"
    []
  end

  def archive_result(record, id)
    creator = Array(record['creator']).join(', ').presence
    { title: Array(record['title']).first, author: creator, writer: creator,
      artist: @type == 'album' ? creator : nil, publisher: Array(record['publisher']).join(', ').presence,
      release_year: record['date'].to_s[/\A\d{4}/], api_id: "archive_#{id}",
      thumbnail_url: "https://archive.org/services/img/#{id}",
      external_url: "https://archive.org/details/#{id}", is_local: false }
  end

  def fetch_open_library(query)
    uri = URI('https://openlibrary.org/search.json')
    uri.query = URI.encode_www_form(q: @type == 'comic' ? "#{query} subject:comics" : query,
                                    limit: 5, fields: 'key,title,author_name,first_publish_year,cover_i,publisher')
    data = JSON.parse(MediaSources::Http.get(uri, deadline: @deadline))
    Array(data['docs']).map do |book|
      { title: book['title'], author: Array(book['author_name']).join(', ').presence,
        writer: Array(book['author_name']).join(', ').presence, publisher: Array(book['publisher']).first,
        release_year: book['first_publish_year'], api_id: "openlibrary_#{book['key']}",
        thumbnail_url: book['cover_i'] ? "https://covers.openlibrary.org/b/id/#{book['cover_i']}-M.jpg" : nil,
        external_url: "https://openlibrary.org#{book['key']}", is_local: false }
    end
  rescue StandardError => e
    Rails.logger.warn "Open Library search failed: #{e.class}"
    []
  end

  def fetch_itunes_tv(query)
    uri = URI('https://itunes.apple.com/search')
    uri.query = URI.encode_www_form(term: query, entity: 'tvSeason', limit: 5)
    Array(JSON.parse(MediaSources::Http.get(uri, deadline: @deadline))['results']).map do |show|
      { title: show['collectionName'] || show['trackName'], network: show['artistName'],
        release_year: show['releaseDate']&.split('-')&.first, api_id: "itunes_#{show['collectionId']}",
        thumbnail_url: show['artworkUrl100']&.sub('100x100bb', '400x400bb'),
        external_url: show['collectionViewUrl'], is_local: false }
    end
  rescue StandardError => e
    Rails.logger.warn "iTunes TV search failed: #{e.class}"
    []
  end

  # --- Books ---

  def fetch_itunes_books(query)
    url = URI("https://itunes.apple.com/search?term=#{CGI.escape(query)}&media=ebook&limit=5&country=US")
    response = MediaSources::Http.get(url, deadline: @deadline)
    data = JSON.parse(response)

    return [] unless data['results']

    results = data['results'].map do |item|
      {
        title: item['trackName'],
        author: item['artistName'],
        publisher: item['sellerName'],
        release_year: item['releaseDate']&.split('-')&.first,
        thumbnail_url: item['artworkUrl100']&.sub('100x100bb', '400x400bb'),
        api_id: "itunes_#{item['trackId']}",
        external_url: item['trackViewUrl'],
        is_local: false
      }
    end
    results.select { |r| r[:thumbnail_url] }
  rescue StandardError => e
    Rails.logger.error "iTunes Books search failed: #{e.class}"
    []
  end
end
# rubocop:enable Metrics/ClassLength
