# frozen_string_literal: true

class TvShow < ApplicationRecord
  include ReadableCatalogUrl
  include LibraryItemFormAttributes

  include StoredMediaCover

  has_one :metadata_refresh, as: :item, dependent: :destroy
  has_one_attached :cover_image
  has_many :tv_episodes, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :edit_suggestions, as: :suggestable, dependent: :destroy
  has_many :library_items, as: :item, dependent: :destroy

  validates :title, presence: true

  after_commit :sync_episodes_from_api, on: %i[create update]

  attr_accessor :refreshing_metadata

  private

  def sync_episodes_from_api
    return if refreshing_metadata
    return unless MediaSources::Registry.enabled?('tvmaze', 'TvShow')

    return if api_id.blank? || !api_id.to_s.match?(/\A\d+\z/)
    return unless saved_change_to_api_id? || tv_episodes.empty?

    episodes_data = fetch_episodes_from_api
    create_tv_episodes(episodes_data) if episodes_data.is_a?(Array)
  end

  def fetch_episodes_from_api
    require 'net/http'
    require 'json'
    url = URI("https://api.tvmaze.com/shows/#{api_id}/episodes")
    response = MediaSources::Http.get(url)
    JSON.parse(response)
  rescue StandardError => e
    Rails.logger.error "Failed to sync TV show episodes: #{e.class}"
    nil
  end

  def create_tv_episodes(episodes_data)
    MetadataChildren.episodes(self, episodes_data)
  end
end
