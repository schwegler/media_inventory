# frozen_string_literal: true

class TvShow < ApplicationRecord
  include LibraryItemFormAttributes

  has_one_attached :cover_image
  has_many :tv_episodes, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  validates :title, presence: true

  after_commit :sync_episodes_from_api, on: %i[create update]

  private

  def sync_episodes_from_api
    return if api_id.blank?
    return unless saved_change_to_api_id? || tv_episodes.empty?

    episodes_data = fetch_episodes_from_api
    create_tv_episodes(episodes_data) if episodes_data.is_a?(Array)
  end

  def fetch_episodes_from_api
    require 'net/http'
    require 'json'
    url = URI("https://api.tvmaze.com/shows/#{api_id}/episodes")
    response = Net::HTTP.get(url)
    JSON.parse(response)
  rescue StandardError => e
    Rails.logger.error "Failed to sync TV show episodes: #{e.message}"
    nil
  end

  def create_tv_episodes(episodes_data)
    tv_episodes.delete_all
    episodes_data.each do |ep|
      tv_episodes.create!(
        name: ep['name'],
        season: ep['season'],
        episode: ep['number'],
        air_date: ep['airdate'],
        summary: ep['summary'],
        thumbnail_url: ep.dig('image', 'original') || ep.dig('image', 'medium')
      )
    end
  end
end
