# frozen_string_literal: true

class ImportGameArtworkJob < ApplicationJob
  queue_as :media_imports
  discard_on ActiveJob::DeserializationError, ActiveRecord::RecordNotFound

  def perform(game)
    batch = GameArtworkBatch.find_or_create_by!(video_game: game)
    batch.update!(state: 'processing', failure_reason: nil)
    id = GameArtworkResolver.steam_id_for(game.api_id)
    unless id
      batch.update!(state: 'unavailable', failure_reason: 'No supported external artwork identifier')
      return
    end
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 25
    candidates = GameProviders::SteamGridDb.new(deadline: deadline).supplemental_artwork(id)
    candidates.concat(steam_candidates(id, deadline))
    acquired = candidates.first(6).count { |candidate| acquire?(game, candidate, deadline) }
    batch.update!(state: acquired.positive? ? 'ready' : 'unavailable',
                  failure_reason: acquired.positive? ? nil : 'No eligible artwork could be acquired')
  rescue StandardError => e
    batch&.update!(state: 'failed', failure_reason: e.class.name)
    raise
  end

  private

  def steam_candidates(id, deadline)
    GameProviders::Steam.new(deadline: deadline).supplemental_artwork(id)
  rescue GameProviders::Base::Unavailable
    []
  end

  def acquire?(game, candidate, deadline)
    return false unless candidate[:storage_eligible] && GameArtwork::KINDS.include?(candidate[:artwork_type])
    return false unless candidate[:url].is_a?(String)

    blob = GameSearchArtwork.acquire(candidate, deadline)
    return false unless blob

    MediaArtworkRendition.request(blob)

    entry = game.game_artworks.find_or_initialize_by(library_item_id: nil, kind: candidate[:artwork_type],
                                                     source_url: candidate[:url])
    entry.assign_attributes(provider: candidate[:provider], author: candidate[:author],
                            attribution_url: candidate[:attribution_url])
    entry.image.attach(blob)
    entry.save!
    true
  end
end
