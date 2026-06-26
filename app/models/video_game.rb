# frozen_string_literal: true

class VideoGame < ApplicationRecord
  include LibraryItemFormAttributes
  include VisibleTo

  has_one_attached :cover_image
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :edit_suggestions, as: :suggestable, dependent: :destroy
  has_many :library_items, as: :item, dependent: :destroy

  validates :title, presence: true

  after_commit :sync_details_from_api, on: %i[create update]

  private

  def sync_details_from_api
    return if api_id.blank?
    return unless saved_change_to_api_id?

    # Handle Steam IDs
    if api_id.start_with?('steam_') || api_id.match?(/^\d+$/)
      sync_steam_details
      return
    end

    if api_id.start_with?('rawg_')
      api_key = ApiConfiguration.find_by(source_name: 'RAWG', is_active: true)&.access_token
      unless api_key
        Rails.logger.warn 'RAWG API key not configured.'
        return
      end

      update_from_rawg_data(fetch_rawg_data(api_key))
    end
  rescue StandardError => e
    Rails.logger.error "Failed to sync Video Game details: #{e.message}"
  end

  def sync_steam_details
    require 'net/http'
    require 'json'
    steam_id = api_id.sub('steam_', '')
    url = URI("https://store.steampowered.com/api/appdetails?appids=#{steam_id}")
    response = Net::HTTP.get(url)
    data = JSON.parse(response).dig(steam_id, 'data') || {}

    date_str = data.dig('release_date', 'date')
    parsed_year = date_str ? date_str.split(',').last&.strip : nil

    update_columns(
      title: data['name'] || title,
      release_year: parsed_year || release_year,
      developer: data['developers']&.first || developer,
      publisher: data['publishers']&.first || publisher,
      thumbnail_url: "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/#{steam_id}/library_600x900.jpg"
    )
  end

  def fetch_rawg_data(api_key)
    require 'net/http'
    require 'json'
    rawg_id = api_id.sub('rawg_', '')
    url = URI("https://api.rawg.io/api/games/#{rawg_id}?key=#{api_key}")
    JSON.parse(Net::HTTP.get(url))
  end

  def update_from_rawg_data(data)
    update_columns(
      title: data['name'] || title,
      release_year: data['released']&.split('-')&.first || release_year,
      developer: data['developers']&.first&.dig('name') || developer,
      publisher: data['publishers']&.first&.dig('name') || publisher,
      thumbnail_url: data['background_image'] || thumbnail_url
    )
  end
end
