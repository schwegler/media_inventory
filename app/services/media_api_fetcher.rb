# frozen_string_literal: true

require 'net/http'
require 'json'

# rubocop:disable Metrics/ClassLength
class MediaApiFetcher
  def self.call(item)
    new(item).call
  end

  def initialize(item)
    @item = item
  end

  def call
    case @item
    when Movie
      fetch_tmdb_movie
      fetch_itunes_movie
    when TvShow
      fetch_tvmaze_show
      fetch_itunes_tv
    when Album
      fetch_musicbrainz_music
      fetch_itunes_music
    when VideoGame
      # Existing logic for Video Games can be reused or skipped if it's already fetching on create
      # We could just query Wikipedia again here
    when Comic
      # No obvious open free API without keys for Comics, so we might just no-op or leave a placeholder
    end
    @item.save if @item.changed?
  end

  private

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def fetch_tmdb_movie
    return unless api_active?('TMDB', 'Movie')

    api_key = ApiConfiguration.find_by(source_name: 'TMDB', is_active: true)&.access_token
    return unless api_key

    uri = URI("https://api.themoviedb.org/3/search/movie?api_key=#{api_key}&query=#{CGI.escape(@item.title)}")
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)

    if data['results']&.any?
      result = data['results'].first

      # Fetch director
      director_url = URI("https://api.themoviedb.org/3/movie/#{result['id']}/credits?api_key=#{api_key}")
      director_response = Net::HTTP.get(director_url)
      director_data = JSON.parse(director_response)
      crew = director_data['crew'] || []
      director = crew.find { |c| c['job'] == 'Director' }

      @item.director = director['name'] if director && @item.director.blank?
      @item.release_year = result['release_date'].to_s[0..3] if @item.release_year.blank?
      if result['poster_path'] && @item.thumbnail_url.blank? && !@item.cover_image.attached?
        @item.thumbnail_url = "https://image.tmdb.org/t/p/w500#{result['poster_path']}"
      end
      @item.external_url = "https://www.themoviedb.org/movie/#{result['id']}" if @item.external_url.blank?
      @item.api_id = result['id'].to_s if @item.api_id.blank?
    end
  rescue StandardError => e
    Rails.logger.error "TMDB API error: #{e.message}"
  end

  def fetch_itunes_movie
    return unless api_active?('itunes', 'Movie')

    uri = URI("https://itunes.apple.com/search?term=#{CGI.escape(@item.title)}&entity=movie&limit=1")
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)

    if data['results']&.any?
      result = data['results'].first
      @item.director = result['artistName'] if @item.director.blank?
      @item.release_year = result['releaseDate'].to_s[0..3] if @item.release_year.blank?
      @item.thumbnail_url = result['artworkUrl100'] if @item.thumbnail_url.blank? && !@item.cover_image.attached?
      @item.external_url = result['trackViewUrl'] if @item.external_url.blank?
    end
  rescue StandardError => e
    Rails.logger.error "iTunes API error: #{e.message}"
  end

  def fetch_itunes_tv
    return unless api_active?('itunes', 'TvShow')

    uri = URI("https://itunes.apple.com/search?term=#{CGI.escape(@item.title)}&entity=tvSeason&limit=1")
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)

    if data['results']&.any?
      result = data['results'].first
      @item.network = result['artistName'] if @item.respond_to?(:network) && @item.network.blank?
      @item.thumbnail_url = result['artworkUrl100'] if @item.thumbnail_url.blank? && !@item.cover_image.attached?
    end
  rescue StandardError => e
    Rails.logger.error "iTunes API error: #{e.message}"
  end

  def fetch_musicbrainz_music
    # Use a generic name, or no check since it's free.
    uri = URI("https://musicbrainz.org/ws/2/release-group?query=#{CGI.escape(@item.title)}&fmt=json")
    req = Net::HTTP::Get.new(uri)
    req['User-Agent'] = 'MediaInventoryApp/1.0'

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(req)
    end
    data = JSON.parse(response.body)

    if data['release-groups']&.any?
      result = data['release-groups'].first
      @item.artist = result.dig('artist-credit', 0, 'name') if @item.artist.blank?
      @item.genre = result.dig('tags', 0, 'name') if @item.genre.blank?
      @item.release_year = result['first-release-date'].to_s[0..3] if @item.release_year.blank?
      if @item.thumbnail_url.blank? && !@item.cover_image.attached?
        @item.thumbnail_url = "https://coverartarchive.org/release-group/#{result['id']}/front-250"
      end
      @item.external_url = "https://musicbrainz.org/release-group/#{result['id']}" if @item.external_url.blank?
      @item.api_id = result['id'].to_s if @item.api_id.blank?
    end
  rescue StandardError => e
    Rails.logger.error "MusicBrainz API error: #{e.message}"
  end

  def fetch_itunes_music
    return unless api_active?('itunes', 'Album')

    uri = URI("https://itunes.apple.com/search?term=#{CGI.escape(@item.title)}&entity=album&limit=1")
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)

    if data['results']&.any?
      result = data['results'].first
      @item.artist = result['artistName'] if @item.artist.blank?
      @item.genre = result['primaryGenreName'] if @item.genre.blank?
      @item.release_year = result['releaseDate'].to_s[0..3] if @item.release_year.blank?
      @item.thumbnail_url = result['artworkUrl100'] if @item.thumbnail_url.blank? && !@item.cover_image.attached?
      @item.external_url = result['collectionViewUrl'] if @item.external_url.blank?
    end
  rescue StandardError => e
    Rails.logger.error "iTunes API error: #{e.message}"
  end
  # rubocop:enable Metrics/AbcSize

  def fetch_tvmaze_show
    return unless api_active?('tvmaze', 'TvShow')

    uri = URI("https://api.tvmaze.com/search/shows?q=#{CGI.escape(@item.title)}")
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)

    if data.any? && data.first['show']
      show = data.first['show']
      @item.network = show.dig('network', 'name') || show.dig('webChannel', 'name') if @item.network.blank?
      @item.thumbnail_url = show.dig('image', 'medium') if @item.thumbnail_url.blank? && !@item.cover_image.attached?
      @item.external_url = show['url'] if @item.external_url.blank?
      @item.api_id = show['id'].to_s if @item.api_id.blank?
    end
  rescue StandardError => e
    Rails.logger.error "TVMaze API error: #{e.message}"
  end

  def api_active?(source_name, media_type)
    # Default to true if no configuration exists, otherwise follow the config
    config = ApiConfiguration.find_by(source_name: source_name, media_type: media_type)
    return config.is_active if config

    true
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
