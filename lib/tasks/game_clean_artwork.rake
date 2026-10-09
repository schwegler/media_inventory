# frozen_string_literal: true

namespace :games do
  desc 'Preview unreferenced remote cover blobs older than 7 days; APPLY=1 purges only unattached blobs'
  task clean_artwork: :environment do
    retained = MediaArtworkRendition.where(source_blob_id: ActiveStorage::Attachment.select(:blob_id))
                                    .where.not(blob_id: nil).select(:blob_id)
    candidates = ActiveStorage::Blob.unattached.where.not(id: retained).where('active_storage_blobs.created_at < ?',
                                                                              7.days.ago)
    candidates.where("active_storage_blobs.key LIKE 'media-covers/%'").find_each do |blob|
      puts "Unreferenced cover blob #{blob.id}: #{blob.byte_size} bytes"
      if ENV['APPLY'] == '1' && blob.attachments.none? && !retained.where(blob_id: blob.id).exists?
        MediaArtworkSource.where(blob_id: blob.id).delete_all
        blob.purge
      end
    end
  end
end
