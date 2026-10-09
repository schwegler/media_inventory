# frozen_string_literal: true

namespace :games do
  desc 'Queue responsive derivatives for up to 50 existing game covers and retry failed/stuck renditions'
  task prepare_images: :environment do
    prepared = MediaArtworkRendition.select(:source_blob_id)
    VideoGame.with_attached_cover_image.joins(:cover_image_attachment)
             .where.not(active_storage_attachments: { blob_id: prepared }).limit(50).each do |game|
      MediaArtworkRendition.request(game.cover_image.blob) if game.cover_image.attached?
    end
    failed = MediaArtworkRendition.where(state: 'failed').or(
      MediaArtworkRendition.where(state: %w[pending processing]).where('updated_at < ?', 5.minutes.ago)
    )
    failed.limit(50).each do |row|
      row.update!(state: 'pending', failure_reason: nil)
      GenerateMediaArtworkRenditionJob.perform_later(row)
    end
    GameArtworkBatch.where(state: %w[pending processing failed]).where('updated_at < ?', 5.minutes.ago)
                    .limit(50).each { |row| ImportGameArtworkJob.perform_later(row.video_game) }
  end
end
