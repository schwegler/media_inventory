# frozen_string_literal: true

class MediaSearchJob < ApplicationJob
  queue_as :media_search

  # Imports and cover downloads must not hold up an interactive search.
  unless Rails.env.test?
    self.queue_adapter = BoundedAsyncAdapter.new(capacity: ENV.fetch('MEDIA_SEARCH_QUEUE_LIMIT', '8').to_i)
  end

  def perform(query, type, key, latest_key = nil)
    if latest_key && MediaSources::Registry::CACHE.read(latest_key) != key
      MediaSources::Registry::CACHE.delete(key)
      return
    end

    results = MediaSearchService.call(query, type) do |partial|
      MediaSources::Registry::CACHE.write(key, { state: 'pending', results: partial }, expires_in: 45.seconds)
    end
    results = GameSearchArtwork.call(results) if type == 'video_game'
    MediaSources::Registry::CACHE.write(key, { state: 'ready', results: results }, expires_in: 15.minutes)
  rescue StandardError => e
    Rails.logger.warn("Media search failed: #{e.class}")
    MediaSources::Registry::CACHE.write(key, { state: 'failed', results: [] }, expires_in: 10.seconds)
  end
end
