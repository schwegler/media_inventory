# frozen_string_literal: true

# Selection and strong provider IDs establish identity. A title does not.
class GameCatalogIdentity
  class Invalid < StandardError; end

  def self.resolve(attributes, token = nil)
    selected = VideoGame.find_signed(token, purpose: 'game-catalog-selection') if token.present?
    raise Invalid, 'Game selection expired or is invalid. Select the game again.' if token.present? && !selected

    api_id = attributes[:api_id].to_s
    match = api_id.match(/\A(steam|rawg)_(\d+)\z/)
    mapped = GameExternalId.find_by(provider: match[1], external_id: match[2])&.video_game if match
    primary = VideoGame.find_by(api_id: api_id) if api_id.present?
    identities = [selected, mapped, primary].compact.uniq(&:id)
    raise Invalid, 'Conflicting game identifiers require catalog review.' if identities.length > 1

    identities.first || VideoGame.new(attributes)
  end
end
