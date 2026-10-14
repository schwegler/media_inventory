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

  def game_library_image(game, library, **)
    image = library&.game_cover_image&.attached? ? library.game_cover_image : game.cover_image
    return image_tag(game.stored_cover_url.presence || '/missing-game-cover.svg', **) unless image.attached?

    fallback = image == game.cover_image ? game.stored_cover_url : nil
    game_artwork_image(image, fallback_url: fallback, **)
  end

  def game_artwork_image(image, fallback_url: nil, **options)
    blob = image.blob
    sources = blob.artwork_renditions.filter_map do |row|
      if row.state == 'ready' && row.blob && row.width&.positive?
        [artwork_rendition_path(row.signed_id(purpose: 'artwork-rendition')), "#{row.width}w"]
      end
    end
    primary = fallback_url.presence || rails_storage_proxy_path(blob)
    primary = sources.min_by { |_, width| width.to_i }&.first || primary
    srcset = sources.uniq(&:last).map { |url, width| "#{url} #{width}" }.join(', ')
    options = { sizes: '(max-width: 600px) 45vw, 240px' }.merge(options)
    image_tag(primary, srcset: srcset.presence, **options)
  end
end
