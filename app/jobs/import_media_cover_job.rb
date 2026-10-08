# frozen_string_literal: true

class ImportMediaCoverJob < ApplicationJob
  queue_as :media_imports
  discard_on ActiveJob::DeserializationError, ActiveRecord::RecordNotFound

  def perform(item, source_url)
    MediaCoverImporter.call(item, source_url)
  end
end
