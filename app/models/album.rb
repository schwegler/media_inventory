# frozen_string_literal: true

class Album < ApplicationRecord
  include ReadableCatalogUrl
  include LibraryItemFormAttributes

  include StoredMediaCover

  has_one :metadata_refresh, as: :item, dependent: :destroy
  has_one_attached :cover_image
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :edit_suggestions, as: :suggestable, dependent: :destroy
  has_many :library_items, as: :item, dependent: :destroy
  validates :title, presence: true

  after_commit :sync_details_from_api, on: %i[create update]

  private

  def sync_details_from_api
    return unless MediaSources::Registry.enabled?('MusicBrainz', 'Album')

    return unless api_id.to_s.match?(/\A(?:musicbrainz_)?[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i)
    return unless saved_change_to_api_id?

    require 'net/http'
    require 'json'
    url = URI("https://musicbrainz.org/ws/2/release-group/#{api_id.delete_prefix('musicbrainz_')}?inc=artist-credits&fmt=json")

    response = MediaSources::Http.get(url)

    data = JSON.parse(response)

    artist_name = data.dig('artist-credit', 0, 'name') || artist
    release_date = data['first-release-date']
    year = release_date&.split('-')&.first || release_year

    update!(
      title: data['title'] || title,
      artist: artist_name,
      release_year: year
    )
  rescue StandardError => e
    Rails.logger.error "Failed to sync Album details: #{e.class}"
  end
end
