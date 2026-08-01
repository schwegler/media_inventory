# frozen_string_literal: true

class TvEpisode < ApplicationRecord
  belongs_to :tv_show
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  def title
    show_title = tv_show&.title
    "#{show_title} S#{season}E#{episode}: #{name}"
  end

  # rubocop:disable Naming/PredicatePrefix
  def is_collected?
    tv_show&.is_collected? || false
  end
  # rubocop:enable Naming/PredicatePrefix

  def in_watchlist?
    false
  end

  def consumed?
    watched?
  end

  def consumed_at
    watched_at
  end

  # Attempt to fetch a thumbnail from TVMaze if this episode is missing one.
  # Called opportunistically when marking an episode as watched or reviewed.
  def attempt_thumbnail_update!
    return if thumbnail_url.present?
    return unless tv_show&.api_id.present? && !tv_show.api_id.to_s.start_with?('tmdb_')

    require 'net/http'
    require 'json'

    url = URI("https://api.tvmaze.com/shows/#{tv_show.api_id}/episodebynumber?season=#{season}&number=#{episode}")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)
    image_url = data.dig('image', 'original') || data.dig('image', 'medium')
    update!(thumbnail_url: image_url) if image_url.present?
  rescue StandardError => e
    Rails.logger.error "Failed to update TV episode thumbnail: #{e.message}"
  end

  # Dirty tracking helper methods to prevent NoMethodErrors from Trackable concern
  def saved_change_to_consumed?
    saved_change_to_watched?
  end

  def saved_change_to_consumed
    saved_change_to_watched
  end

  def saved_change_to_is_collected?
    false
  end

  def saved_change_to_is_collected
    nil
  end

  def saved_change_to_in_watchlist?
    false
  end

  def saved_change_to_in_watchlist
    nil
  end
end
