# frozen_string_literal: true

# Portable imports use existing strong mappings. They never merge catalog records
# or call a provider based on a title alone.
class GameImportIdentity
  def self.resolve(data)
    game = data['game']
    raise GameCollectionImport::Invalid, 'Missing game identity' unless game.is_a?(Hash)

    mappings = Array(data['external_ids'])
    raise GameCollectionImport::Invalid, 'Invalid external identifiers' unless
      mappings.length <= 20 && mappings.all?(Hash)

    identities = mappings.map { |row| row.slice('provider', 'external_id') }
    match = game['api_id'].to_s.match(/\A(steam|rawg)_(\d+)\z/)
    identities << { 'provider' => match[1], 'external_id' => match[2] } if match
    ids = identities.filter_map do |row|
      GameExternalId.find_by(provider: row['provider'].to_s, external_id: row['external_id'].to_s)&.video_game_id
    end.uniq
    raise GameCollectionImport::Invalid, 'Conflicting provider identifiers require review' if ids.length > 1

    return VideoGame.find(ids.first) if ids.one?
    raise GameCollectionImport::Invalid, 'Provider identifiers are unmatched; reconcile them before importing' if
      identities.any?

    resolve_internal(game)
  end

  def self.resolve_internal(game)
    id = game['id'].to_s
    raise GameCollectionImport::Invalid, 'A valid canonical game ID is required' unless id.match?(/\A\d+\z/)

    result = VideoGame.find_by(id: id)
    raise GameCollectionImport::Invalid, 'Canonical game no longer exists' unless result
    if game['title'].present? && game['title'].to_s.strip.casecmp?(result.title.strip) == false
      raise GameCollectionImport::Invalid, 'Catalog ID and title disagree; reconcile external identifiers first'
    end

    result
  end
end
