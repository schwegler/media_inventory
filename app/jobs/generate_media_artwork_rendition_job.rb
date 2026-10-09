# frozen_string_literal: true

class GenerateMediaArtworkRenditionJob < ApplicationJob
  queue_as :media_imports
  discard_on ActiveJob::DeserializationError, ActiveRecord::RecordNotFound

  def perform(row)
    row.update!(state: 'processing', failure_reason: nil)
    source = row.source_blob
    source.open do |original|
      width, height = MediaArtworkDecoder.validate!(original.path)
      source.update!(metadata: source.metadata.merge('width' => width, 'height' => height))
      geometry = "#{row.requested_width}x#{row.requested_height}"
      MediaArtworkDecoder.normalized(original.path, dimensions: geometry) do |preview|
        blob = MediaArtworkDownload.store_blob(preview, source.metadata['remote_source'])
        row.update!(blob: blob, width: blob.metadata['width'], height: blob.metadata['height'], state: 'ready')
      end
    end
  rescue ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError, MediaSources::Http::Error,
         IOError, SystemCallError => e
    row.update!(state: 'failed', failure_reason: e.class.name)
  end
end
