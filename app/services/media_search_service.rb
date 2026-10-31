# frozen_string_literal: true

require 'net/http'
require 'json'

# rubocop:disable-next Metrics/ClassLength
class MediaSearchService
  REQUEST_LOCK = Mutex.new

  def self.source_states(query, type)
    MediaSources::Registry::CACHE.read(source_state_key(query, type)) || []
  end

  def self.source_state_key(query, type)
    ['discovery-sources-v1', type, query.to_s.strip.first(200).downcase,
     ApiConfiguration.order(:id).pluck(:source_name, :media_type, :is_active, :updated_at)]
  end

  def self.call(query, type, &)
    new(query, type).call(&)
  end

  # Browser polling releases Puma threads while background workers search.
  def self.request(query, type, client_id: nil)
    fingerprint = ApiConfiguration.order(:id).pluck(:source_name, :media_type, :is_active, :updated_at)
    key = ['async-search-v3', Digest::SHA256.hexdigest([query.to_s.strip.first(200).downcase, type, fingerprint].to_json)]
    cache = MediaSources::Registry::CACHE
    latest_key = ['search-client-v1', client_id] if client_id.to_s.match?(/\A[a-zA-Z0-9-]{16,64}\z/)
    REQUEST_LOCK.synchronize do
      cache.write(latest_key, key, expires_in: 2.minutes) if latest_key
      state = cache.read(key)
      return state if state

      cache.write(key, { state: 'pending', results: [] }, expires_in: 45.seconds)
      unless MediaSearchJob.perform_later(query.to_s.strip.first(200), type, key, latest_key)
        state = { state: 'failed', results: [] }
        cache.write(key, state, expires_in: 10.seconds)
        return state
      end
      { state: 'pending', results: [] }
    end
  end

  def initialize(query, type)
    @query = query.to_s.strip.first(200)
    @type = type
  end

  def call(&progress)
    return [] if @query.blank?

    return [] unless SOURCES.key?(@type)

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @deadline = started_at + 12
    MediaSources::Registry::CACHE.fetch(
      ['media-search-v10', @type, @query.downcase.strip,
       ApiConfiguration.order(:id).pluck(:source_name, :media_type, :is_active, :updated_at)], expires_in: 15.minutes
    ) do
      results = search_sources(&progress)
      results = ComicSearchQuery.new(@query).rank(results).first(20) if @type == 'comic'
      # Games need bounded detail lookup to distinguish DLC and resolve real cover candidates.
      # Other media fetch details only after an explicit selection.
      results = rank_results(results)
      if @type == 'video_game'
        @deadline = started_at + 18
        results = results.each_with_index.map { |result, index| index < 5 ? enrich_result(result) : result }
      end
      rank_results(results)
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

  def search_sources
    sources = SOURCES.fetch(@type)
    if @type == 'video_game'
      priorities = ENV.fetch('GAME_METADATA_PROVIDER_PRIORITY', 'Steam,RAWG,Wikipedia').split(',')
      sources = sources.sort_by { |source, _method| priorities.index(source) || 99 }
    end
    @source_state_key = self.class.source_state_key(@query, @type)
    @state_lock = Mutex.new
    @source_states = []
    configurations = ApiConfiguration.order(:id).to_a
    sources = MediaSources::Registry.with_snapshot(configurations) do
      (sources + [['InternetArchive', :fetch_internet_archive]]).select do |source, _method|
        MediaSources::Registry.enabled?(source, @type.camelize)
      end
    end
    @source_states = sources.map { |source, _| { source: source, state: 'pending' } }
    store_source_states
    collect_sources(sources, configurations) { |results| yield results if block_given? }
  end

  def collect_sources(sources, configurations)
    completed = Queue.new
    workers = sources.each_with_index.map do |(source, method), index|
      search_worker(source, method, index, configurations, completed)
    end
    batches = Array.new(sources.size) { [] }
    ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
      sources.size.times do
        index, results = completed.pop
        batches[index] = results
        partial = batches.flatten.map(&:dup)
        partial = ComicSearchQuery.new(@query).rank(partial) if @type == 'comic'
        yield rank_results(partial) if block_given? && @type != 'video_game'
      end
      workers.each(&:value)
    end
    batches.flatten
  ensure
    ActiveSupport::Dependencies.interlock.permit_concurrent_loads { workers&.each(&:join) }
  end

  def search_worker(source, method, index, configurations, completed)
    Thread.new do
      Rails.application.executor.wrap do
        results = MediaSources::Registry.with_snapshot(configurations) do
          Thread.current[:media_search_failure] = false
          results = send(method, @query).map { |result| result.merge(source: source) }
          record_source_state(source, Thread.current[:media_search_failure] ? 'unavailable' : 'ready')
          results
        end
        completed << [index, results]
      end
    rescue StandardError => e
      Rails.logger.warn("#{source} search failed: #{e.class}")
      record_source_state(source, 'unavailable')
      completed << [index, []]
    end
  end

  def record_source_state(source, state)
    @state_lock.synchronize do
      @source_states.find { |entry| entry[:source] == source }[:state] = state
      store_source_states
    end
  end

  def store_source_states
    MediaSources::Registry::CACHE.write(@source_state_key, @source_states, expires_in: 15.minutes)
  end

  def rank_results(results)
    return GameSearchQuery.new(@query).rank(results).first(20) if @type == 'video_game'

    results = BookSearchQuery.new(@query).rank(results) if @type == 'book'
    filter_unique_results(results).first(20)
  end

  def enrich_result(result)
    return result if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= @deadline
    return result unless %w[TMDB ComicVine RAWG Steam MusicBrainz tvmaze TVMaze].include?(result[:source])

    item = @type.camelize.constantize.new
    result.each { |field, value| item.public_send("#{field}=", value) if item.has_attribute?(field) }
    fields, = MetadataProvider.new(item, include_children: false, deadline: @deadline).call
    result.merge(fields.compact_blank) do |field, original, detail|
      @type == 'video_game' && %i[thumbnail_url game_type].include?(field) ? detail : original.presence || detail
    end
  rescue MetadataProvider::Unavailable, MetadataProvider::RateLimited, MetadataProvider::Unsupported,
         JSON::ParserError, Timeout::Error, SocketError, KeyError
    result
  end

  def filter_unique_results(all_results)
    seen = {}
    all_results.select do |item|
      next false if item[:title].blank?

      key = [item[:title].to_s.downcase.strip, item[:release_year].to_s, item[:artist].to_s.downcase.strip,
             item[:author].to_s.downcase.strip]

      key += [item[:book_format], item[:api_id]] if @type == 'book'

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

  def source_unavailable
    Thread.current[:media_search_failure] = true
    []
  end

  def fetch_tmdb_movies(query)
    api_key = MediaSources::Registry.token('TMDB', @type.camelize)
    return source_unavailable if api_key.blank?

    url = URI("https://api.themoviedb.org/3/search/movie?api_key=#{api_key}&query=#{CGI.escape(query)}")
    response = MediaSources::Http.cached_get(url, expires_in: 15.minutes, deadline: @deadline)
    data = JSON.parse(response)

    return [] unless data['results']

    data['results'].slice(0, 5).map do |item|
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
  rescue StandardError => e
    Thread.current[:media_search_failure] = true
    Rails.logger.error "TMDB Movie search failed: #{e.class}"
    []
  end

  def fetch_itunes_movies(query)
    url = URI("https://itunes.apple.com/search?term=#{CGI.escape(query)}&entity=movie&limit=5&country=US")
    response = MediaSources::Http.cached_get(url, expires_in: 15.minutes, deadline: @deadline)
    data = JSON.parse(response)

    return [] unless data['results']

    data['results'].map do |item|
      {
        title: item['trackName'],
        director: item['artistName'],
        genre: item['primaryGenreName'],
        release_year: item['releaseDate']&.split('-')&.first,
        thumbnail_url: item['artworkUrl100']&.sub('100x100bb', '400x400bb'),
        api_id: "itunes_#{item['trackId']}",
        external_url: item['trackViewUrl'],
        is_local: false
      }
    end
  rescue StandardError => e
    Thread.current[:media_search_failure] = true
    Rails.logger.error "iTunes Movie search failed: #{e.class}"
    []
  end

  # --- Albums ---

  def fetch_itunes_albums(query)
    url = URI("https://itunes.apple.com/search?term=#{CGI.escape(query)}&media=music&entity=album&limit=5&country=US")
    response = MediaSources::Http.cached_get(url, expires_in: 15.minutes, deadline: @deadline)
    data = JSON.parse(response)

    return [] unless data['results']

    data['results'].map do |item|
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
  rescue StandardError => e
    Thread.current[:media_search_failure] = true
    Rails.logger.error "iTunes Album search failed: #{e.class}"
    []
  end

  def fetch_musicbrainz_albums(query)
    url = URI("https://musicbrainz.org/ws/2/release-group?query=#{CGI.escape(query)}&fmt=json")
    res = MediaSources::Http.cached_get(url, expires_in: 15.minutes, deadline: @deadline)
    data = JSON.parse(res)

    return [] unless data['release-groups']

    # MusicBrainz returns singles alongside albums (often with the same title).
    # Importing a single's correct track list must not masquerade as a full album.
    data['release-groups'].select { |item| %w[Album EP].include?(item['primary-type']) }.first(5).map do |item|
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
    Thread.current[:media_search_failure] = true
    Rails.logger.error "MusicBrainz Album search failed: #{e.class}"
    []
  end
  # --- Comics ---

  def fetch_comicvine_comics(query)
    api_key = MediaSources::Registry.token('ComicVine', 'Comic')
    return source_unavailable if api_key.blank?

    search = ComicSearchQuery.new(query)
    results = []
    offset = 0
    loop do
      url = build_comicvine_url(query, api_key, offset: offset)
      data = JSON.parse(MediaSources::Http.cached_get(url, expires_in: 15.minutes, deadline: @deadline))
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
    Thread.current[:media_search_failure] = true
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
    return source_unavailable if api_key.blank?

    url = URI("https://api.themoviedb.org/3/search/tv?api_key=#{api_key}&query=#{CGI.escape(query)}")
    response = MediaSources::Http.cached_get(url, expires_in: 15.minutes, deadline: @deadline)
    data = JSON.parse(response)

    return [] unless data['results']

    data['results'].slice(0, 5).map do |item|
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
  rescue StandardError => e
    Thread.current[:media_search_failure] = true
    Rails.logger.error "TMDB TV search failed: #{e.class}"
    []
  end

  def fetch_tvmaze_tv_shows(query)
    url = URI("https://api.tvmaze.com/search/shows?q=#{CGI.escape(query)}")
    response = MediaSources::Http.cached_get(url, expires_in: 15.minutes, deadline: @deadline)
    data = JSON.parse(response)

    data.slice(0, 5).map do |item|
      map_tvmaze_show(item['show'])
    end
  rescue StandardError => e
    Thread.current[:media_search_failure] = true
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
      genre: Array(show['genres']).join(', ').presence,
      release_year: show['premiered']&.split('-')&.first,
      thumbnail_url: show['image'] ? (show['image']['original'] || show['image']['medium']) : nil,
      api_id: show['id'].to_s,
      external_url: show['officialSite'] || show['url'],
      is_local: false
    }
  end

  # --- Video Games ---

  def fetch_steam_video_games(query)
    GameProviders::Steam.new(deadline: @deadline).search(query)
  rescue GameProviders::Base::Unavailable
    source_unavailable
  end

  def fetch_rawg_video_games(query)
    GameProviders::Rawg.new(deadline: @deadline).search(query)
  rescue GameProviders::Base::Unavailable
    source_unavailable
  end

  def fetch_wikipedia(query)
    category = { 'movie' => 'film', 'tv_show' => 'television series', 'album' => 'album',
                 'comic' => 'comic', 'video_game' => 'video game', 'book' => 'book' }.fetch(@type)
    uri = URI('https://en.wikipedia.org/w/api.php')
    uri.query = URI.encode_www_form(action: 'query', generator: 'search', gsrsearch: "#{query} #{category}",
                                    gsrlimit: 3, prop: 'pageimages|info', piprop: 'thumbnail',
                                    pithumbsize: 500, pilicense: 'any',
                                    inprop: 'url', format: 'json')
    data = JSON.parse(MediaSources::Http.cached_get(uri, expires_in: 15.minutes, deadline: @deadline))
    (data.dig('query', 'pages') || {}).values.sort_by { |page| page['index'].to_i }.filter_map do |page|
      next unless page.dig('thumbnail', 'source')

      { title: page['title'].sub(/\s*\([^)]*\)$/, ''), thumbnail_url: page.dig('thumbnail', 'source'),
        api_id: "wiki_#{page['pageid']}", external_url: page['fullurl'], is_local: false }
    end
  rescue StandardError => e
    Thread.current[:media_search_failure] = true
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
    data = JSON.parse(MediaSources::Http.cached_get(uri, expires_in: 15.minutes, deadline: @deadline))
    Array(data.dig('response', 'docs')).filter_map do |record|
      id = record['identifier']
      next unless id.to_s.match?(/\A[a-zA-Z0-9_.-]+\z/)

      archive_result(record, id)
    end
  rescue StandardError => e
    Thread.current[:media_search_failure] = true
    Rails.logger.warn "Internet Archive search failed: #{e.class}"
    []
  end

  def archive_result(record, id)
    creator = Array(record['creator']).join(', ').presence
    { title: Array(record['title']).first, author: @type == 'book' ? creator : nil,
      writer: @type == 'comic' ? creator : nil, metadata_credits_data: archive_credits(record),
      artist: @type == 'album' ? creator : nil, publisher: Array(record['publisher']).join(', ').presence,
      release_year: record['date'].to_s[/\A\d{4}/], api_id: "archive_#{id}",
      thumbnail_url: "https://archive.org/services/img/#{id}",
      external_url: "https://archive.org/details/#{id}", is_local: false }
  end

  def archive_credits(record)
    role = { 'book' => 'Author', 'comic' => 'Writer', 'album' => 'Album artist' }.fetch(@type, 'Contributor')
    kind = @type == 'album' ? 'artist' : 'person'
    Array(record['creator']).filter_map do |name|
      ProviderEntityMetadata.credit({ 'name' => name }, role, 'InternetArchive', kind: kind)
    end
  end

  def fetch_open_library(query)
    uri = URI('https://openlibrary.org/search.json')
    uri.query = URI.encode_www_form(q: @type == 'comic' ? "#{query} subject:comics" : query,
                                    limit: 5,
                                    fields: 'key,title,author_name,first_publish_year,cover_i,publisher,isbn,edition_key')
    data = JSON.parse(MediaSources::Http.cached_get(uri, expires_in: 15.minutes, deadline: @deadline))
    Array(data['docs']).map do |book|
      { title: book['title'], author: Array(book['author_name']).join(', ').presence,
        writer: Array(book['author_name']).join(', ').presence, publisher: Array(book['publisher']).first,
        release_year: book['first_publish_year'], api_id: "openlibrary_#{book['key']}",
        thumbnail_url: book['cover_i'] ? "https://covers.openlibrary.org/b/id/#{book['cover_i']}-M.jpg" : nil,
        external_url: "https://openlibrary.org#{book['key']}", is_local: false }
    end
  rescue StandardError => e
    Thread.current[:media_search_failure] = true
    Rails.logger.warn "Open Library search failed: #{e.class}"
    []
  end

  def fetch_itunes_tv(query)
    uri = URI('https://itunes.apple.com/search')
    uri.query = URI.encode_www_form(term: query, entity: 'tvSeason', limit: 5)
    Array(JSON.parse(MediaSources::Http.cached_get(uri, expires_in: 15.minutes,
                                                        deadline: @deadline))['results']).map do |show|
      { title: show['collectionName'] || show['trackName'], network: show['artistName'],
        genre: show['primaryGenreName'],
        release_year: show['releaseDate']&.split('-')&.first, api_id: "itunes_#{show['collectionId']}",
        thumbnail_url: show['artworkUrl100']&.sub('100x100bb', '400x400bb'),
        external_url: show['collectionViewUrl'], is_local: false }
    end
  rescue StandardError => e
    Thread.current[:media_search_failure] = true
    Rails.logger.warn "iTunes TV search failed: #{e.class}"
    []
  end

  # --- Books ---

  def fetch_itunes_books(query)
    # Independent requests: a failing format must not hide the other format.
    %w[ebook audiobook].flat_map { |format| fetch_apple_book_format(query, format) }
  end

  def fetch_apple_book_format(query, format)
    uri = URI('https://itunes.apple.com/search')
    uri.query = URI.encode_www_form(term: query, media: format, limit: 25, country: 'US')
    data = JSON.parse(MediaSources::Http.cached_get(uri, expires_in: 15.minutes, deadline: @deadline))
    Array(data['results']).filter_map { |item| BookProviderMetadata.apple(item, format: format) }
  rescue StandardError => e
    Thread.current[:media_search_failure] = true
    Rails.logger.warn "Apple Books #{format} search failed: #{e.class}"
    []
  end
end
