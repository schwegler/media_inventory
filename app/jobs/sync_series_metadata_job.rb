# frozen_string_literal: true

class SyncSeriesMetadataJob < ApplicationJob
  queue_as :media_imports
  discard_on ActiveJob::DeserializationError, ActiveRecord::RecordNotFound

  def perform(item)
    case item
    when TvShow then item.send(:sync_episodes_from_api)
    when Comic then item.send(:sync_issues_from_api)
    when TvEpisode then item.attempt_thumbnail_update!
    end
  end
end
