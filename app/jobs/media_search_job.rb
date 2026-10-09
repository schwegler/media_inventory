# frozen_string_literal: true

class MediaSearchJob < ApplicationJob
  queue_as :media_imports

  def perform(query, type, key)
    results = MediaSearchService.call(query, type)
    results = GameSearchArtwork.call(results) if type == 'video_game'
    MediaSources::Registry::CACHE.write(key, { state: 'ready', results: results }, expires_in: 15.minutes)
  rescue StandardError => e
    Rails.logger.warn("Media search failed: #{e.class}")
    MediaSources::Registry::CACHE.delete(key)
  end
end
