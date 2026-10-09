# frozen_string_literal: true

namespace :games do
  desc 'Validate game cover checksums and pixels; APPLY=1 marks corrupted remote covers and queues repair'
  task audit_artwork: :environment do
    VideoGame.with_attached_cover_image.find_each do |game|
      next unless game.cover_image.attached?

      begin
        game.cover_image.blob.open { |file| MediaCoverImporter.validate_pixels!(file.path) }
      rescue ActiveStorage::IntegrityError, ActiveStorage::FileNotFoundError, MediaSources::Http::Error
        puts "Game #{game.id}: corrupted or missing cover"
        next unless ENV['APPLY'] == '1' && game.cover_image.blob.metadata['remote_source'].present?

        health = CoverImport.find_or_create_by!(item: game) { |entry| entry.source_url = game.thumbnail_url }
        health.update!(state: 'failed', failure_reason: 'Corrupted stored image')
        ImportMediaCoverJob.perform_later(game, game.thumbnail_url) if game.thumbnail_url.present?
      end
    end
  end
end
