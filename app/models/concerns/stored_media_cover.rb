# frozen_string_literal: true

module StoredMediaCover
  extend ActiveSupport::Concern

  included do
    after_commit :enqueue_cover_import, on: %i[create update]
  end

  # thumbnail_url is retained as provenance, never used to render saved media.
  def stored_cover_url
    Rails.application.routes.url_helpers.rails_blob_path(cover_image, only_path: true) if cover_image.attached?
  end

  private

  def enqueue_cover_import
    return if thumbnail_url.blank? || !saved_change_to_thumbnail_url?
    return if cover_image.attached? && !cover_image.blob.metadata['remote_source']

    ImportMediaCoverJob.perform_later(self, thumbnail_url)
  end
end
