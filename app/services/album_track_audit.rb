# frozen_string_literal: true

require 'digest'
require 'timeout'

# Read-only planning for a separately approved repair. Never creates refresh rows,
# changes source identities, imports tracks, or updates personal/library records.
class AlbumTrackAudit
  FIELDS = %w[id provider_id title disc_number track_number duration_ms isrc content_rating release_date credits].freeze

  def initialize(ids:, limit: 10, after_id: 0, output: $stdout)
    @ids = Array(ids).map { |id| Integer(id.to_s, 10) }.uniq.sort
    raise ArgumentError, 'Explicit positive album IDs are required' if @ids.empty? || @ids.any? { |id| id <= 0 }

    @limit = Integer(limit)
    @after_id = Integer(after_id)
    raise ArgumentError, 'LIMIT must be 1..50 and AFTER_ID non-negative' unless (1..50).cover?(@limit) && @after_id >= 0

    @output = output
  end

  def run
    checkpoint = @after_id
    @ids.select { |id| id > @after_id }.first(@limit).each do |id|
      sleep 1.1 # Also spaces the first request after the previous album's release lookup.
      result = report(Album.find(id))
      retryable = %w[rate_limited unavailable failed partial].include?(result[:source_state])
      checkpoint = id unless retryable
      @output.puts(result.merge(checkpoint_after_id: checkpoint, dry_run: true).to_json)
      @output.flush
      break if retryable
    end
  end

  def report(album)
    existing = album.album_tracks.order(:id).map { |track| track.attributes.slice(*FIELDS) }
    snapshot = { album_id: album.id, api_id: album.api_id, external_url: album.external_url, tracks: existing }
    evidence = snapshot.merge(snapshot_sha256: Digest::SHA256.hexdigest(snapshot.to_json))
    adapter = MetadataProvider.new(album, revalidate: true, fresh: true,
                                          deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + 12)
    fields, rows = Timeout.timeout(12) { adapter.call }
    classification = classify(album, fields, existing, rows)
    source = { provider: adapter.provider, release_id: adapter.album_release_id, rows: rows }
    eligible = !adapter.partial && %w[missing partial].include?(classification)
    additions = rows.reject { |row| existing.any? { |track| track['provider_id'] == row['provider_id'] } }
    evidence.merge(classification: classification, source_state: adapter.partial ? 'partial' : 'complete',
                   provider_evidence: source, evidence_sha256: Digest::SHA256.hexdigest(source.to_json),
                   eligible_for_review: eligible, proposed_additions: eligible ? additions : [])
  rescue MetadataProvider::Unsupported
    evidence.merge(classification: 'unsupported', source_state: 'unsupported', eligible_for_review: false)
  rescue MetadataProvider::RateLimited
    evidence.merge(classification: 'unknown', source_state: 'rate_limited', eligible_for_review: false)
  rescue MetadataProvider::Unavailable
    evidence.merge(classification: 'unknown', source_state: 'unavailable', eligible_for_review: false)
  rescue StandardError => e
    evidence.merge(classification: 'unknown', source_state: 'failed', error_class: e.class.name, eligible_for_review: false)
  end

  private

  def classify(album, fields, existing, rows)
    type = fields.dig(:metadata_details, 'primary-type') || album.metadata_details['primary-type']
    return 'wrong_edition' if type == 'Single'

    AlbumMetadata.validate_edition!(album.album_tracks.to_a, rows)
    return 'missing' if existing.empty?
    return 'user_modified_or_unverified' if changed_fields?(existing, rows)
    return 'already_complete' if existing.map { |track| track['provider_id'] }.sort == rows.pluck('provider_id').sort

    'partial'
  rescue AlbumMetadata::EditionConflict
    'wrong_edition'
  end

  def changed_fields?(existing, rows)
    existing.any? do |track|
      row = rows.find { |candidate| candidate['provider_id'] == track['provider_id'] }
      row.nil? || row.any? { |field, value| track[field].present? && track[field] != value }
    end
  end
end
