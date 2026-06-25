# frozen_string_literal: true

class Movie < ApplicationRecord
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

    config = ApiConfiguration.find_by(source_name: 'TMDB', is_active: true)
    api_key = config&.access_token
    unless api_key
      Rails.logger.warn 'TMDB API key not configured.'
      return
    end

    require 'net/http'
    require 'json'
    url = URI("https://api.themoviedb.org/3/movie/#{api_id}?api_key=#{api_key}")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)

    update_columns(
      title: data['title'] || title,
      release_year: data['release_date']&.split('-')&.first || release_year,
      thumbnail_url: data['poster_path'] ? "https://image.tmdb.org/t/p/w500#{data['poster_path']}" : thumbnail_url
    )
  rescue StandardError => e
    Rails.logger.error "Failed to sync Movie details: #{e.message}"
  end
end
