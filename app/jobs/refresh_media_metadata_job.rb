# frozen_string_literal: true

class RefreshMediaMetadataJob < ApplicationJob
  queue_as :media_imports
  discard_on ActiveJob::DeserializationError, ActiveRecord::RecordNotFound

  def perform(item, user)
    MetadataRefresher.new(item, user).call(claimed: true)
  end
end
