# frozen_string_literal: true

module StoredMediaCover
  extend ActiveSupport::Concern

  included do
    after_commit :enqueue_cover_import, on: %i[create update]
  end

  # Legacy records and interrupted imports recover through the app on first use.
  # The browser never fetches the provider URL directly for saved catalog media.
  def stored_cover_url
    return if thumbnail_url.blank? && !cover_image.attached?

    Rails.application.routes.url_helpers.media_cover_path(type: self.class.name.underscore, id: id)
  end

  private

  def enqueue_cover_import
    return if thumbnail_url.blank? || !saved_change_to_thumbnail_url?
    return if cover_image.attached? && !cover_image.blob.metadata['remote_source']

    health = CoverImport.find_or_create_by!(item: self) { |entry| entry.source_url = thumbnail_url }
    queue_limit = ENV.fetch('MEDIA_ARTWORK_QUEUE_LIMIT', '100').to_i.clamp(1, 10_000)
    if CoverImport.where(state: %w[pending processing]).count >= queue_limit
      health.update!(state: 'failed', failure_reason: 'Artwork queue limit reached')
      return
    end
    health.update!(source_url: thumbnail_url, state: 'pending', failure_reason: nil)
    ImportMediaCoverJob.perform_later(self, thumbnail_url)
  end
end
