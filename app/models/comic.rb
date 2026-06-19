# frozen_string_literal: true

class Comic < ApplicationRecord
  include LibraryItemFormAttributes

  has_one_attached :cover_image
  has_many :comic_issues, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  validates :title, presence: true

  after_commit :sync_issues_from_api, on: %i[create update]

  private

  def sync_issues_from_api
    return if api_id.blank?
    return unless saved_change_to_api_id? || comic_issues.empty?

    editions = fetch_editions_from_api
    create_comic_issues(editions) if editions.is_a?(Array)
  end

  def fetch_editions_from_api
    require 'net/http'
    require 'json'
    url = URI("https://openlibrary.org/works/#{api_id}/editions.json?limit=50")
    response = Net::HTTP.get(url)
    JSON.parse(response)['entries']
  rescue StandardError => e
    Rails.logger.error "Failed to sync Comic editions: #{e.message}"
    nil
  end

  def create_comic_issues(editions)
    comic_issues.delete_all
    editions.each do |ed|
      cover_id = ed['covers']&.first
      cover_url = cover_id ? "https://covers.openlibrary.org/b/id/#{cover_id}-L.jpg" : nil
      pub = ed['publishers']&.first

      comic_issues.create!(
        title: ed['title'],
        release_date: ed['publish_date'],
        publisher: pub,
        thumbnail_url: cover_url
      )
    end
  end
end
