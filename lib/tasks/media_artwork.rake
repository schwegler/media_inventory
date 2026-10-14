# frozen_string_literal: true

namespace :media_artwork do
  desc 'Queue missing artwork sizes for existing covers and supplemental artwork (bounded by queue limit)'
  task prepare_sizes: :environment do
    blob_ids = ActiveStorage::Attachment.where(name: %w[cover_image game_cover_image image]).select(:blob_id)
    ActiveStorage::Blob.where(id: blob_ids).find_each do |blob|
      next unless blob.image?
      next if blob.artwork_renditions.count >= MediaArtworkRendition::SIZES.length

      MediaArtworkRendition.request(blob)
    end
  end
end
