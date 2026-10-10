# frozen_string_literal: true

# Metadata identity and artwork provenance are deliberately independent.
class GameArtworkResolver
  def self.candidates(result, results: [], deadline: nil, alternate: false)
    steam_id = steam_id_for(result[:api_id])
    adapter = GameProviders::SteamGridDb.new(deadline: deadline)
    candidates = steam_id && adapter.enabled? ? adapter.artwork(steam_id) : []
    candidates << steam_portrait(steam_id) if steam_id && !alternate
    primary = primary_candidate(result) unless alternate
    candidates << primary if primary
    candidates.concat(matched_candidates(result, results))
    priorities = ENV.fetch('GAME_ARTWORK_PROVIDER_PRIORITY', 'SteamGridDB,Steam,RAWG,Wikipedia').split(',')
    candidates.uniq { |candidate| candidate[:url] }.each_with_index
              .sort_by { |candidate, index| [priorities.index(candidate[:provider]) || 99, index] }.map(&:first)
  end

  def self.steam_portrait(steam_id)
    { url: "https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/#{steam_id}/library_600x900_2x.jpg",
      provider: 'Steam', provider_id: steam_id.to_s, artwork_type: 'portrait_cover',
      matched_by: 'steam_app_id', storage_eligible: true }
  end

  def self.primary_candidate(result)
    return if result[:thumbnail_url].blank? || result[:source] == 'InternetArchive'

    { url: result[:thumbnail_url], provider: result[:source] || 'catalog', provider_id: result[:api_id],
      artwork_type: 'cover', matched_by: 'provider_id', storage_eligible: true }
  end

  def self.matched_candidates(result, results)
    results.filter_map do |other|
      next if other[:source] == 'InternetArchive' || other.equal?(result)
      next if other[:thumbnail_url].blank? || other[:thumbnail_url] == result[:thumbnail_url]
      next unless confident_same_game?(result, other)

      { url: other[:thumbnail_url], provider: other[:source], provider_id: other[:api_id],
        artwork_type: 'cover', matched_by: 'title_year_developer_type', storage_eligible: true }
    end
  end

  def self.steam_id_for(api_id)
    value = api_id.to_s[/\A(?:steam_)?(\d+)\z/, 1]
    return value if value

    match = api_id.to_s.match(/\A(rawg)_(\d+)\z/)
    return unless match

    identity = GameExternalId.find_by(provider: match[1], external_id: match[2])
    return unless identity

    identity.video_game.game_external_ids.find_by(provider: 'steam')&.external_id
  end

  def self.confident_same_game?(left, right)
    return true if left[:api_id].present? && left[:api_id] == right[:api_id]

    left[:game_type] == 'game' && right[:game_type] == 'game' &&
      left[:title].to_s.downcase.strip == right[:title].to_s.downcase.strip &&
      left[:release_year].present? && left[:release_year].to_s == right[:release_year].to_s &&
      left[:developer].present? && left[:developer].to_s.downcase.strip == right[:developer].to_s.downcase.strip
  end
end
