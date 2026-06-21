# frozen_string_literal: true

class Book < ApplicationRecord
  include LibraryItemFormAttributes

  has_one_attached :cover_image
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :edit_suggestions, as: :suggestable, dependent: :destroy

  validates :title, presence: true

  after_commit :sync_details_from_api, on: %i[create update]

  private

  def sync_details_from_api
    return if api_id.blank?
    return unless saved_change_to_api_id?

    require 'net/http'
    require 'json'

    url = URI("https://itunes.apple.com/lookup?id=#{api_id}")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)

    return unless data['results'] && data['results'].any?

    item = data['results'].first

    update_columns(
      title: item['trackName'] || title,
      author: item['artistName'] || author,
      publisher: item['sellerName'] || publisher,
      release_year: item['releaseDate']&.split('-')&.first || release_year,
      thumbnail_url: item['artworkUrl100']&.sub('100x100bb', '400x400bb') || thumbnail_url,
      external_url: item['trackViewUrl'] || external_url
    )
  rescue StandardError => e
    Rails.logger.error "Failed to sync Book details: #{e.message}"
  end
end
