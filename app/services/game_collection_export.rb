# frozen_string_literal: true

require 'csv'

class GameCollectionExport
  def self.json(library)
    {
      version: 1, game: library.item.attributes.slice('id', 'title', 'api_id', 'platform', 'release_year', 'game_type'),
      external_ids: library.item.game_external_ids.map { |entry| entry.attributes.slice('provider', 'external_id') },
      collection: library.attributes.except('user_id'), copies: library.game_copies.map(&:attributes),
      playthroughs: library.game_playthroughs.includes(:game_sessions).map do |entry|
        entry.attributes.merge('sessions' => entry.game_sessions.map(&:attributes))
      end,
      journal: library.game_journal_entries.map(&:attributes)
    }.to_json
  end

  def self.csv(library)
    CSV.generate do |output|
      output << ['game_id', *GameCollectionImport::COPY_FIELDS]
      library.game_copies.each do |copy|
        output << [library.item_id, *GameCollectionImport::COPY_FIELDS.map { |field| copy.public_send(field) }]
      end
    end
  end
end
