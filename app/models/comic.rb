# frozen_string_literal: true

class Comic < ApplicationRecord
  include ReadableCatalogUrl
  include LibraryItemFormAttributes

  include StoredMediaCover

  has_one :metadata_refresh, as: :item, dependent: :destroy
  has_one_attached :cover_image
  has_many :comic_issues, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :edit_suggestions, as: :suggestable, dependent: :destroy
  has_many :library_items, as: :item, dependent: :destroy

  validates :title, presence: true

  after_commit :sync_issues_from_api, on: %i[create update]

  attr_accessor :refreshing_metadata

  private

  def sync_issues_from_api
    return if refreshing_metadata
    return if api_id.blank? || !api_id.to_s.match?(/\A\d+\z/)
    return unless saved_change_to_api_id? || comic_issues.empty?

    issues_data = fetch_issues_from_api
    create_comic_issues(issues_data) if issues_data.is_a?(Array)
  end

  def fetch_issues_from_api
    api_key = MediaSources::Registry.token('ComicVine', 'Comic')
    if api_key.blank?
      Rails.logger.warn 'ComicVine API key not configured.'
      return nil
    end

    all_issues = []
    offset = 0

    loop do
      data = fetch_comicvine_page(api_key, offset)
      results = data['results'] || []
      all_issues.concat(results)

      offset += 100
      break if offset >= data['number_of_total_results'].to_i || results.empty?

      sleep 1
    end

    all_issues
  rescue StandardError => e
    Rails.logger.error "Failed to sync Comic issues: #{e.class}"
    nil
  end

  def fetch_comicvine_page(api_key, offset)
    require 'net/http'
    require 'json'
    url = URI('https://comicvine.gamespot.com/api/issues/')
    url.query = URI.encode_www_form(
      api_key: api_key, format: 'json', filter: "volume:#{api_id}",
      sort: 'issue_number:asc', limit: 100, offset: offset
    )
    response = MediaSources::Http.get(url)
    JSON.parse(response)
  end

  def create_comic_issues(issues_data)
    MetadataChildren.issues(self, issues_data)
  end
end
