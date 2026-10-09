# frozen_string_literal: true

module VideoGamesHelper
  def game_playtime(minutes)
    minutes = minutes.to_f.round
    "#{minutes / 60}h #{minutes % 60}m"
  end

  def game_library_cover(game, library)
    return url_for(library.game_cover_image) if library&.game_cover_image&.attached?

    game.stored_cover_url.presence || '/missing-game-cover.svg'
  end
end
