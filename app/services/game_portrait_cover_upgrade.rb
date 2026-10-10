# frozen_string_literal: true

# Refresh provider covers without replacing uploaded artwork or discarding a usable fallback.
class GamePortraitCoverUpgrade
  def self.call(game)
    steam_id = GameArtworkResolver.steam_id_for(game.api_id)
    return :skipped unless steam_id

    original = game.cover_image.blob if game.cover_image.attached?
    return :skipped if original && (original.metadata['remote_source'].blank? || portrait?(original))

    result = { api_id: game.api_id, source: 'Steam', thumbnail_url: game.thumbnail_url }
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
    candidates = GameArtworkResolver.candidates(result, deadline: deadline)
    candidates.select { |candidate| candidate[:artwork_type] == 'portrait_cover' }.each do |candidate|
      blob = GameSearchArtwork.acquire(candidate, deadline)
      next unless blob && portrait?(blob)

      return replace(game, original, blob)
    end
    :unavailable
  end

  def self.portrait?(blob)
    blob.metadata['height'].to_i > blob.metadata['width'].to_i
  end

  def self.replace(game, original, blob)
    game.with_lock do
      current = game.cover_image.blob if game.cover_image.attached?
      return :skipped unless current&.id == original&.id

      game.cover_image.attach(blob)
    end
    :updated
  end
end
