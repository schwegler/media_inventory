# frozen_string_literal: true

namespace :media do
  desc 'Add new default sources without changing existing settings'
  task seed_sources: :environment do
    ApiConfiguration.seed_defaults!
  end

  desc 'Import legacy remote covers in bounded batches (TYPE=VideoGame AFTER_ID=0 LIMIT=100)'
  task import_covers: :environment do
    allowed = %w[Movie TvShow Album VideoGame Comic Book TvEpisode ComicIssue]
    type = ENV.fetch('TYPE', 'VideoGame')
    abort 'Unsupported TYPE' unless allowed.include?(type)

    limit = ENV.fetch('LIMIT', '100').to_i.clamp(1, 500)
    records = type.constantize.where('id > ?', ENV.fetch('AFTER_ID', '0').to_i)
                  .where.not(thumbnail_url: [nil, '']).order(:id).limit(limit).with_attached_cover_image
    records.each do |item|
      next if item.cover_image.attached?

      # Run one download at a time; resumable without a large job queue.
      MediaCoverImporter.call(item, item.thumbnail_url)
      puts "#{type} #{item.id}: #{item.cover_image.attached? ? 'stored' : 'unavailable'}"
    end
    puts "Next AFTER_ID=#{records.last&.id || ENV.fetch('AFTER_ID', '0')}"
  end
end

namespace :media do
  desc 'Purge old unattached imported covers in small batches (LIMIT=100)'
  task prune_covers: :environment do
    limit = ENV.fetch('LIMIT', '100').to_i.clamp(1, 500)
    blobs = ActiveStorage::Blob.unattached.where('key LIKE ?', 'media-covers/%')
                               .where('created_at < ?', 7.days.ago).order(:id).limit(limit)
    blobs.each(&:purge)
    puts 'Finished pruning old unattached imported covers.'
  end
end
