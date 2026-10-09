# frozen_string_literal: true

class ImportMediaCoverJob < ApplicationJob
  class RetryableImport < StandardError; end
  retry_on RetryableImport, wait: :polynomially_longer, attempts: 3

  queue_as :media_imports
  discard_on ActiveJob::DeserializationError, ActiveRecord::RecordNotFound

  def perform(item, source_url)
    MediaCoverImporter.call(item, source_url)
    health = CoverImport.find_by(item: item)
    raise RetryableImport if health&.state == 'failed' && health.source_url == source_url
  end
end
