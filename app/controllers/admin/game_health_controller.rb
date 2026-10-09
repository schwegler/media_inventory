# frozen_string_literal: true

module Admin
  class GameHealthController < ApplicationController
    def index
      @imports = CoverImport.where(item_type: 'VideoGame').order(attempted_at: :desc).limit(50)
      @counts = CoverImport.where(item_type: 'VideoGame').group(:state).count
      @missing = VideoGame.left_joins(:cover_image_attachment).where(active_storage_attachments: { id: nil }).count
      references = ActiveStorage::Attachment.where(record_type: 'VideoGame', name: 'cover_image')
      blobs = ActiveStorage::Blob.where(id: references.select(:blob_id))
      @bytes = blobs.sum(:byte_size)
      @assets = blobs.count
      @references = ActiveStorage::Attachment.where(record_type: 'VideoGame', name: 'cover_image').count
      @providers = %w[Steam RAWG Wikipedia].map do |source|
        [source, MediaSources::Registry.enabled?(source, 'VideoGame'),
         source != 'RAWG' || MediaSources::Registry.token(source, 'VideoGame').present?,
         MediaSources::Registry::CACHE.read(['game-provider-health', source]) || { state: 'unprobed' }]
      end
    end

    def retry
      entry = CoverImport.where(item_type: 'VideoGame').find(params[:id])
      ImportMediaCoverJob.perform_later(entry.item, entry.item.thumbnail_url) if entry.item.thumbnail_url.present?
      redirect_to admin_game_health_path, notice: 'Artwork retry queued.', status: :see_other
    end
  end
end
