# frozen_string_literal: true

namespace :games do
  desc 'Preview unreferenced remote cover blobs older than 7 days; APPLY=1 purges only unattached blobs'
  task clean_artwork: :environment do
    ActiveStorage::Blob.unattached.where('created_at < ?',
                                         7.days.ago).where("key LIKE 'media-covers/%'").find_each do |blob|
      puts "Unreferenced cover blob #{blob.id}: #{blob.byte_size} bytes"
      if ENV['APPLY'] == '1' && blob.attachments.none?
        MediaArtworkSource.where(blob_id: blob.id).delete_all
        blob.purge
      end
    end
  end
end
