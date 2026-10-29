# frozen_string_literal: true

namespace :metadata do
  desc 'DRY RUN only: audit explicit album IDs (IDS=5,17 LIMIT=10 AFTER_ID=0 DRY_RUN=1); emits JSONL, never writes records'
  task audit_album_tracks: :environment do
    raise ArgumentError, 'This command is dry-run only; apply requires a separately reviewed repair' unless
      ENV.fetch('DRY_RUN', '1') == '1'

    AlbumTrackAudit.new(ids: ENV.fetch('IDS', '').split(','), limit: ENV.fetch('LIMIT', '10'),
                        after_id: ENV.fetch('AFTER_ID', '0')).run
  end
end
