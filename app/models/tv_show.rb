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

  after_commit :enqueue_series_sync, on: %i[create update]

  attr_accessor :refreshing_metadata

  private

  def enqueue_series_sync
    return if refreshing_metadata || api_id.blank? || !api_id.to_s.match?(/\A(?:tmdb_)?\d+\z/)
    return unless saved_change_to_api_id? || tv_episodes.empty?

    SyncSeriesMetadataJob.perform_later(self)
  end

  def sync_episodes_from_api
    return if refreshing_metadata
    return sync_tmdb_episodes if api_id.to_s.match?(/\Atmdb_\d+\z/)
    return unless MediaSources::Registry.enabled?('tvmaze', 'TvShow')

    return if api_id.blank? || !api_id.to_s.match?(/\A\d+\z/)
    return unless saved_change_to_api_id? || tv_episodes.empty?

    sync_show_details_from_api
    episodes_data = fetch_episodes_from_api
    create_tv_episodes(episodes_data) if episodes_data.is_a?(Array)
  end

  def sync_show_details_from_api
    url = URI("https://api.tvmaze.com/shows/#{api_id}?embed[]=cast&embed[]=crew")
    response = MediaSources::Http.cached_get(url)
    data = JSON.parse(response)
    return unless data.is_a?(Hash)

    apply_tvmaze_show_attributes(data)
  rescue StandardError => e
    Rails.logger.error "Failed to sync TV show details: #{e.class}"
  end

  def sync_tmdb_episodes
    fields, rows = MetadataProvider.new(self).call
    missing_fields = fields.compact_blank.select { |field, _| public_send(field).blank? }
    update_columns(missing_fields) if missing_fields.present?
    create_tv_episodes(rows)
  rescue MetadataProvider::Unavailable, MetadataProvider::RateLimited => e
    Rails.logger.warn "Failed to sync TMDB episodes: #{e.class}"
  end

  def apply_tvmaze_show_attributes(data)
    directors, writers, cast = extract_tvmaze_credits(data['_embedded'])
    year = data['premiered'] ? data['premiered'].split('-').first.to_i : nil

    update_columns(
      director: director.presence || directors,
      writer: writer.presence || writers,
      actors: actors.presence || cast,
      genre: genre.presence || Array(data['genres']).join(', ').presence,
      release_year: release_year.presence || (year if year&.positive?)
    )
  end

  def extract_tvmaze_credits(embedded)
    return [nil, nil, nil] if embedded.blank?

    cast = Array(embedded['cast']).slice(0, 10).filter_map { |c| c.dig('person', 'name') }.uniq.join(', ').presence
    crew = Array(embedded['crew'])
    directors = crew.select { |c| c['type'].to_s.downcase.include?('director') }
                    .filter_map { |c| c.dig('person', 'name') }.uniq.first(5).join(', ').presence
    writer_roles = ['creator', 'writer', 'developer', 'story', 'head writer']
    writers = crew.select { |c| writer_roles.any? { |t| c['type'].to_s.downcase.include?(t) } }
                  .filter_map { |c| c.dig('person', 'name') }.uniq.first(5).join(', ').presence
    [directors, writers, cast]
  end

  def fetch_episodes_from_api
    require 'net/http'
    require 'json'
    url = URI("https://api.tvmaze.com/shows/#{api_id}/episodes")
    response = MediaSources::Http.cached_get(url)
    JSON.parse(response)
  rescue StandardError => e
    Rails.logger.error "Failed to sync TV show episodes: #{e.class}"
    nil
  end

  def create_tv_episodes(episodes_data)
    MetadataChildren.episodes(self, episodes_data)
  end
end
