# frozen_string_literal: true

class Comic < ApplicationRecord
  include LibraryItemFormAttributes

  has_one_attached :cover_image
  has_many :comic_issues, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :edit_suggestions, as: :suggestable, dependent: :destroy

  validates :title, presence: true

  after_commit :sync_issues_from_api, on: %i[create update]

  private

  def sync_issues_from_api
    return if api_id.blank?
    return unless saved_change_to_api_id? || comic_issues.empty?

    issues_data = fetch_issues_from_api
    create_comic_issues(issues_data) if issues_data.is_a?(Array)
  end

  def fetch_issues_from_api
    api_key = ApiConfiguration.find_by(source_name: 'ComicVine', is_active: true)&.access_token
    unless api_key
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
    Rails.logger.error "Failed to sync Comic issues: #{e.message}"
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
    req = Net::HTTP::Get.new(url)
    req['User-Agent'] = 'MediaInventoryApp/1.0'
    res = Net::HTTP.start(url.hostname, url.port, use_ssl: url.scheme == 'https') do |http|
      http.request(req)
    end
    JSON.parse(res.body)
  end

  def create_comic_issues(issues_data)
    comic_issues.delete_all
    issues_data.each do |issue|
      cover_url = issue.dig('image', 'original_url') || issue.dig('image', 'medium_url')

      comic_issues.create!(
        title: issue['name'],
        issue_number: issue['issue_number']&.to_i,
        release_date: issue['cover_date'],
        summary: issue['description'] || issue['deck'],
        thumbnail_url: cover_url
      )
    end
  end
end
