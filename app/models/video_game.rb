# frozen_string_literal: true

class VideoGame < ApplicationRecord
  include LibraryItemFormAttributes

  has_one_attached :cover_image
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  validates :title, presence: true

  after_commit :sync_details_from_api, on: %i[create update]

  private

  def sync_details_from_api
    return if api_id.blank?
    return unless saved_change_to_api_id?

    api_key = ApiConfiguration.find_by(source_name: 'RAWG', is_active: true)&.access_token
    unless api_key
      Rails.logger.warn 'RAWG API key not configured.'
      return
    end

    update_from_rawg_data(fetch_rawg_data(api_key))
  rescue StandardError => e
    Rails.logger.error "Failed to sync Video Game details: #{e.message}"
  end

  def fetch_rawg_data(api_key)
    require 'net/http'
    require 'json'
    url = URI("https://api.rawg.io/api/games/#{api_id}?key=#{api_key}")
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
