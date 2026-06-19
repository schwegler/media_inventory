# frozen_string_literal: true

require 'net/http'
require 'json'

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
      fetch_itunes_movie
    when TvShow
      fetch_tvmaze_show
      fetch_itunes_tv
    when Album
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

  # rubocop:disable Metrics/AbcSize
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
