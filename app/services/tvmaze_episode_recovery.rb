# frozen_string_literal: true

require 'digest'

# Operator-only catalog repair: no route, no automatic run, and no library edits.
# Preview one source season and explicitly approve its digest before a bounded
# create-only batch. Never use the normal enrichment/completion fan-out here.
class TvmazeEpisodeRecovery
  MAX_BATCH = 250

  def initialize(show, expected_api_id:, season:, after_number: 0, batch_size: MAX_BATCH)
    raise ArgumentError, 'Expected a saved TV show' unless show.is_a?(TvShow) && show.persisted?
    raise ArgumentError, 'Invalid TVMaze identity' unless expected_api_id.to_s.match?(/\A\d+\z/)
    raise ArgumentError, 'Invalid season' unless season.is_a?(Integer) && season >= 0
    raise ArgumentError, 'Invalid episode cursor' unless after_number.is_a?(Integer) && after_number >= 0
    raise ArgumentError, 'Invalid batch size' unless batch_size.is_a?(Integer) && (1..MAX_BATCH).cover?(batch_size)

    @show = show
    @expected_id = expected_api_id.to_s
    @season = season
    @after_number = after_number
    @batch_size = batch_size
  end

  def call(dry_run: true, expected_digest: nil)
    raise ArgumentError, 'Invalid dry-run mode' unless [true, false].include?(dry_run)

    verify_source!
    batch, more = source_batch
    digest = Digest::SHA256.hexdigest(batch.to_json)
    raise ArgumentError, 'Preview digest required or source batch changed' if !dry_run && expected_digest != digest

    return report(batch, digest, more, dry_run: true) if dry_run

    @show.with_lock do
      verify_source!
      report(batch, digest, more, dry_run: false)
    end
  end

  private

  def report(batch, digest, more, dry_run:)
    existing = @show.tv_episodes.where(season: @season, episode: batch.map { |row| row['number'] }).pluck(:episode)
    missing = batch.reject { |row| existing.include?(row['number']) }
    created = dry_run ? 0 : MetadataChildren.episodes(@show, missing, episode_only: true)
    { show_id: @show.id, api_id: @expected_id, season: @season, after_number: @after_number,
      batch_size: batch.size, would_create: missing.size, skipped_existing: batch.size - missing.size,
      created: created, dry_run: dry_run, digest: digest,
      next_after_number: more ? batch.last.fetch('number') : nil }
  end

  def verify_source!
    raise ArgumentError, 'Stored source does not match expected TVMaze identity' unless @show.reload.api_id == @expected_id
    raise MetadataProvider::Unavailable unless MediaSources::Registry.enabled?('tvmaze', 'TvShow')
  end

  def source_batch
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
    seasons = list("shows/#{@expected_id}/seasons", deadline)
    matches = seasons.select { |s| s.is_a?(Hash) && s['number'] == @season && s['id'].is_a?(Integer) && s['id'].positive? }
    raise ArgumentError, 'Source season missing or ambiguous' unless matches.one?

    rows = list("seasons/#{matches.sole.fetch('id')}/episodes", deadline)
    rows = rows.select do |row|
      regular_episode?(row)
    end
    rows.sort_by! { |row| row['number'] }
    raise ArgumentError, 'Duplicate source episode numbers' unless rows.map { |row| row['number'] }.uniq.size == rows.size

    [rows.first(@batch_size), rows.size > @batch_size]
  end

  def regular_episode?(row)
    row.is_a?(Hash) && row['season'] == @season && row['number'].is_a?(Integer) &&
      row['number'] > @after_number && !row['type'].to_s.end_with?('_special')
  end

  def list(path, deadline)
    rows = JSON.parse(MediaSources::Http.cached_get("https://api.tvmaze.com/#{path}", deadline: deadline, revalidate: true))
    raise JSON::ParserError, 'Expected a provider list' unless rows.is_a?(Array)

    rows
  end
end
