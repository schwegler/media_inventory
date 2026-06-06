# frozen_string_literal: true

class TvShow < ApplicationRecord
  include Trackable

  belongs_to :user, optional: true
  has_one_attached :cover_image
  has_many :tv_episodes, dependent: :destroy

  validates :title, presence: true

  after_commit :sync_episodes_from_api, on: %i[create update]

  private

  def sync_episodes_from_api
    return if api_id.blank?
    return unless saved_change_to_api_id? || tv_episodes.empty?

    begin
      require 'net/http'
      require 'json'
      url = URI("https://api.tvmaze.com/shows/#{api_id}/episodes")
      response = Net::HTTP.get(url)
      episodes_data = JSON.parse(response)
      if episodes_data.is_a?(Array)
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
    rescue StandardError => e
      Rails.logger.error "Failed to sync TV show episodes: #{e.message}"
    end
  end
end
