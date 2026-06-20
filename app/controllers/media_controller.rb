# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class MediaController < ApplicationController
  before_action :logged_in_user, only: :copy

  def copy
    source_type = params[:source_type].to_s.strip
    allowed_types = %w[Movie TvShow TvEpisode Album Comic VideoGame]
    unless allowed_types.include?(source_type)
      redirect_back fallback_location: root_path, alert: 'Invalid media type.'
      return
    end

    klass = source_type.constantize
    item = klass.find(params[:source_id])

    unless can_access?(item)
      redirect_to root_path, alert: 'Not authorized'
      return
    end

    new_item = build_copied_item(item, params[:target_list].to_s.strip)

    if new_item.save
      redirect_to new_item, notice: "#{klass.model_name.human} added to your #{params[:target_list]}."
    else
      redirect_back fallback_location: root_path, alert: 'Failed to add item.'
    end
  end

  def autocomplete
    q = params[:q].to_s.strip
    type = params[:type].to_s.strip

    if q.blank?
      render json: []
      return
    end

    results = case type
              when 'movie' then autocomplete_movies(q)
              when 'album' then autocomplete_albums(q)
              when 'comic' then autocomplete_comics(q)
              when 'tv_show' then autocomplete_tv_shows(q)
              when 'video_game' then autocomplete_video_games(q)
              else []
              end

    render json: results
  end

  private

  def build_copied_item(item, target_list)
    new_item = item.dup
    new_item.user = current_user

    if target_list == 'collection'
      new_item.is_collected = true
      new_item.in_watchlist = false
    else
      new_item.is_collected = false
      new_item.in_watchlist = true
      new_item.consumed = false
    end

    new_item.cover_image.attach(item.cover_image.blob) if item.cover_image.attached?
    new_item
  end

  def autocomplete_movies(query)
    local_results = fetch_local_movies(query)
    web_results_tmdb = fetch_tmdb_movies(query)
    web_results_itunes = fetch_itunes_movies(query)

    filter_unique_results(local_results + web_results_tmdb + web_results_itunes)
  end

  def fetch_local_movies(query)
    Movie.where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(5).map do |m|
      {
        title: m.title,
        director: m.director,
        release_year: m.release_year,
        thumbnail_url: m.cover_image.attached? ? url_for(m.cover_image) : m.thumbnail_url,
        api_id: m.api_id,
        external_url: m.external_url,
        is_local: true
      }
    end
  end

  def fetch_tmdb_movies(query)
    return [] if Rails.env.test?

    api_key = ApiConfiguration.find_by(source_name: 'TMDB', is_active: true)&.access_token
    return [] unless api_key

    require 'net/http'
    require 'json'
    url = URI("https://api.themoviedb.org/3/search/movie?api_key=#{api_key}&query=#{CGI.escape(query)}")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)

    return [] unless data['results']

    results = data['results'].slice(0, 5).map do |item|
      director = fetch_tmdb_director(item['id'], api_key)
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
    Rails.logger.error "TMDB Movie search failed: #{e.message}"
    []
  end

  def fetch_tmdb_director(movie_id, api_key)
    require 'net/http'
    require 'json'
    url = URI("https://api.themoviedb.org/3/movie/#{movie_id}/credits?api_key=#{api_key}")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)
    crew = data['crew'] || []
    director = crew.find { |c| c['job'] == 'Director' }
    director ? director['name'] : ''
  rescue StandardError => e
    Rails.logger.error "TMDB Credits fetch failed for #{movie_id}: #{e.message}"
    ''
  end

  def fetch_itunes_movies(query)
    return [] if Rails.env.test?

    require 'net/http'
    require 'json'
    url = URI("https://itunes.apple.com/search?term=#{CGI.escape(query)}&entity=movie&limit=5&country=US")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)

    return [] unless data['results']

    results = data['results'].map do |item|
      {
        title: item['trackName'],
        director: item['artistName'],
        release_year: item['releaseDate']&.split('-')&.first,
        thumbnail_url: item['artworkUrl100']&.sub('100x100bb', '400x400bb'),
        api_id: item['trackId'].to_s,
        external_url: item['trackViewUrl'],
        is_local: false
      }
    end
    results.select { |r| r[:thumbnail_url] }
  rescue StandardError => e
    Rails.logger.error "iTunes Movie search failed: #{e.message}"
    []
  end

  def autocomplete_albums(query)
    local_results = fetch_local_albums(query)
    web_results_itunes = fetch_itunes_albums(query)
    web_results_musicbrainz = fetch_musicbrainz_albums(query)

    filter_unique_results(local_results + web_results_itunes + web_results_musicbrainz)
  end

  def fetch_local_albums(query)
    Album.where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(5).map do |a|
      {
        title: a.title,
        artist: a.artist,
        genre: a.genre,
        release_year: a.release_year,
        thumbnail_url: a.cover_image.attached? ? url_for(a.cover_image) : a.thumbnail_url,
        api_id: a.api_id,
        external_url: a.external_url,
        is_local: true
      }
    end
  end

  def fetch_itunes_albums(query)
    return [] if Rails.env.test?

    require 'net/http'
    require 'json'
    url = URI("https://itunes.apple.com/search?term=#{CGI.escape(query)}&media=music&entity=album&limit=5&country=US")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)

    return [] unless data['results']

    results = data['results'].map do |item|
      {
        title: item['collectionName'],
        artist: item['artistName'],
        genre: item['primaryGenreName'],
        release_year: item['releaseDate']&.split('-')&.first,
        thumbnail_url: item['artworkUrl100']&.sub('100x100bb', '500x500bb'),
        api_id: item['collectionId'].to_s,
        external_url: item['collectionViewUrl'],
        is_local: false
      }
    end
    results.select { |r| r[:thumbnail_url] }
  rescue StandardError => e
    Rails.logger.error "iTunes Album search failed: #{e.message}"
    []
  end

  # rubocop:disable Metrics/MethodLength
  def fetch_musicbrainz_albums(query)
    return [] if Rails.env.test?

    require 'net/http'
    require 'json'
    url = URI("https://musicbrainz.org/ws/2/release-group?query=#{CGI.escape(query)}&fmt=json")
    req = Net::HTTP::Get.new(url)
    req['User-Agent'] = 'MediaInventoryApp/1.0'

    res = Net::HTTP.start(url.hostname, url.port, use_ssl: url.scheme == 'https') do |http|
      http.request(req)
    end
    data = JSON.parse(res.body)

    return [] unless data['release-groups']

    data['release-groups'].slice(0, 5).map do |item|
      artist_name = item.dig('artist-credit', 0, 'name') || ''
      {
        title: item['title'],
        artist: artist_name,
        genre: item.dig('tags', 0, 'name') || '',
        release_year: item['first-release-date']&.split('-')&.first,
        thumbnail_url: "https://coverartarchive.org/release-group/#{item['id']}/front-250",
        api_id: item['id'].to_s,
        external_url: "https://musicbrainz.org/release-group/#{item['id']}",
        is_local: false
      }
    end
  rescue StandardError => e
    Rails.logger.error "MusicBrainz Album search failed: #{e.message}"
    []
  end
  # rubocop:enable Metrics/MethodLength

  def autocomplete_comics(query)
    local_results = fetch_local_comics(query)
    web_results = fetch_comicvine_comics(query)

    filter_unique_results(local_results + web_results)
  end

  def fetch_local_comics(query)
    Comic.where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(5).map do |c|
      {
        title: c.title,
        writer: c.writer,
        artist: c.artist,
        publisher: c.publisher,
        issue_number: c.issue_number,
        thumbnail_url: c.cover_image.attached? ? url_for(c.cover_image) : c.thumbnail_url,
        api_id: c.api_id,
        external_url: c.external_url,
        is_local: true
      }
    end
  end

  def fetch_comicvine_comics(query)
    return [] if Rails.env.test?

    api_key = ApiConfiguration.find_by(source_name: 'ComicVine', is_active: true)&.access_token
    return [] unless api_key

    require 'net/http'
    require 'json'
    url = build_comicvine_url(query, api_key)
    req = Net::HTTP::Get.new(url)
    req['User-Agent'] = 'MediaInventoryApp/1.0'

    res = Net::HTTP.start(url.hostname, url.port, use_ssl: url.scheme == 'https') do |http|
      http.request(req)
    end

    parse_comicvine_results(JSON.parse(res.body))
  rescue StandardError => e
    Rails.logger.error "ComicVine search failed: #{e.message}"
    []
  end

  def build_comicvine_url(query, api_key)
    url = URI('https://comicvine.gamespot.com/api/search/')
    url.query = URI.encode_www_form(
      api_key: api_key, format: 'json', query: query, resources: 'volume', limit: 5
    )
    url
  end

  def parse_comicvine_results(data)
    return [] unless data && data['results']

    data['results'].map do |item|
      {
        title: item['name'],
        publisher: item.dig('publisher', 'name'),
        release_year: item['start_year'],
        thumbnail_url: item.dig('image', 'original_url') || item.dig('image', 'medium_url'),
        api_id: item['id']&.to_s,
        external_url: item['site_detail_url'],
        is_local: false
      }
    end
  end

  def autocomplete_tv_shows(query)
    local_results = fetch_local_tv_shows(query)
    web_results = fetch_tmdb_tv_shows(query)
    web_results = fetch_tvmaze_tv_shows(query) if web_results.empty?

    filter_unique_results(local_results + web_results)
  end

  def fetch_local_tv_shows(query)
    TvShow.where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(5).map do |t|
      {
        title: t.title,
        network: t.network,
        thumbnail_url: t.cover_image.attached? ? url_for(t.cover_image) : t.thumbnail_url,
        api_id: t.api_id,
        external_url: t.external_url,
        is_local: true
      }
    end
  end

  def fetch_tmdb_tv_shows(query)
    return [] if Rails.env.test?

    api_key = ApiConfiguration.find_by(source_name: 'TMDB', is_active: true)&.access_token
    return [] unless api_key

    require 'net/http'
    require 'json'
    url = URI("https://api.themoviedb.org/3/search/tv?api_key=#{api_key}&query=#{CGI.escape(query)}")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)

    return [] unless data['results']

    results = data['results'].slice(0, 5).map do |item|
      {
        title: item['name'],
        network: '',
        release_year: item['first_air_date']&.split('-')&.first,
        thumbnail_url: item['poster_path'] ? "https://image.tmdb.org/t/p/w500#{item['poster_path']}" : nil,
        api_id: item['id'].to_s,
        external_url: "https://www.themoviedb.org/tv/#{item['id']}",
        is_local: false
      }
    end
    results.select { |r| r[:thumbnail_url] }
  rescue StandardError => e
    Rails.logger.error "TMDB TV search failed: #{e.message}"
    []
  end

  def fetch_tvmaze_tv_shows(query)
    return [] if Rails.env.test?

    require 'net/http'
    require 'json'
    url = URI("https://api.tvmaze.com/search/shows?q=#{CGI.escape(query)}")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)

    results = data.slice(0, 5).map do |item|
      map_tvmaze_show(item['show'])
    end
    results.select { |r| r[:thumbnail_url] }
  rescue StandardError => e
    Rails.logger.error "TVMaze search failed: #{e.message}"
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

  def autocomplete_video_games(query)
    local_results = fetch_local_video_games(query)
    web_results = fetch_steam_video_games(query)
    wiki_results = Rails.env.test? ? [] : query_wikipedia_video_games(query)

    filter_unique_results(local_results + web_results + wiki_results)
  end

  def fetch_local_video_games(query)
    VideoGame.where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(3).map do |vg|
      {
        title: vg.title,
        developer: vg.developer,
        publisher: vg.publisher,
        platform: vg.platform,
        release_year: vg.release_year,
        thumbnail_url: vg.cover_image.attached? ? url_for(vg.cover_image) : vg.thumbnail_url,
        api_id: vg.api_id,
        external_url: vg.external_url,
        is_local: true
      }
    end
  end

  def fetch_steam_video_games(query) # rubocop:disable Metrics/MethodLength
    return [] if Rails.env.test?

    begin
      require 'net/http'
      require 'json'
      uri = URI("https://store.steampowered.com/api/storesearch/?term=#{CGI.escape(query)}&l=english&cc=US")
      response = Net::HTTP.get(uri)
      data = JSON.parse(response)
      return [] unless data && data['items']

      data['items'].slice(0, 5).map do |item|
        app_id = item['id']
        platforms = []
        if item['platforms']
          platforms << 'PC' if item['platforms']['windows']
          platforms << 'Mac' if item['platforms']['mac']
          platforms << 'Linux' if item['platforms']['linux']
        end
        {
          title: item['name'],
          developer: '',
          publisher: '',
          platform: platforms.join(', '),
          release_year: nil,
          thumbnail_url: "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/#{app_id}/library_600x900.jpg",
          api_id: app_id.to_s,
          external_url: "https://store.steampowered.com/app/#{app_id}",
          is_local: false
        }
      end
    rescue StandardError => e
      Rails.logger.error "Steam Store Search error: #{e.message}"
      []
    end
  end

  def filter_unique_results(all_results)
    seen = {}
    all_results.select do |item|
      key = "#{item[:title].to_s.downcase.strip}_#{item[:release_year]}"

      if seen[key]
        false
      else
        seen[key] = true
      end
    end
  end

  def query_wikipedia_video_games(query)
    require 'net/http'
    require 'json'
    search_url = 'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=' \
                 "#{CGI.escape("#{query} video game")}&format=json&origin=*"
    uri = URI(search_url)
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)
    search_results = data.dig('query', 'search') || []

    search_results.first(3).map { |result| parse_wikipedia_game(result) }.compact
  rescue StandardError => e
    Rails.logger.error "Wikipedia video game search failed: #{e.message}"
    []
  end

  def parse_wikipedia_game(result)
    page_title = result['title']
    summary_url = "https://en.wikipedia.org/api/rest_v1/page/summary/#{CGI.escape(page_title.gsub(' ', '_'))}"
    sum_response = Net::HTTP.get(URI(summary_url))
    sum_data = begin
      JSON.parse(sum_response)
    rescue StandardError
      {}
    end

    return nil unless sum_data['originalimage'] && sum_data['originalimage']['source']

    desc = sum_data['description'] || ''
    year_match = desc.match(/\b(19\d\d|20\d\d)\b/)
    release_year = year_match ? year_match[1].to_i : nil

    {
      title: sum_data['title'],
      developer: 'Nintendo / Various',
      publisher: '',
      platform: 'Console / Various',
      release_year: release_year,
      thumbnail_url: sum_data['originalimage']['source'],
      api_id: "wiki_#{sum_data['pageid'] || page_title}",
      external_url: sum_data.dig('content_urls', 'desktop', 'page'),
      is_local: false
    }
  end
end
# rubocop:enable Metrics/ClassLength
