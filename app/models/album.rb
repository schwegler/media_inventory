# frozen_string_literal: true

class Album < ApplicationRecord
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

    require 'net/http'
    require 'json'
    url = URI("https://musicbrainz.org/ws/2/release/#{api_id}?inc=artist-credits+recordings&fmt=json")

    req = Net::HTTP::Get.new(url)
    req['User-Agent'] = 'MediaInventoryApp/1.0 ( media@example.com )'

    response = Net::HTTP.start(url.hostname, url.port, use_ssl: url.scheme == 'https') do |http|
      http.request(req)
    end

    data = JSON.parse(response.body)

    artist_name = data.dig('artist-credit', 0, 'name') || artist
    release_date = data['date']
    year = release_date&.split('-')&.first || release_year

    update_columns(
      title: data['title'] || title,
      artist: artist_name,
      release_year: year
    )
  rescue StandardError => e
    Rails.logger.error "Failed to sync Album details: #{e.message}"
  end
end
