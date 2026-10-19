# frozen_string_literal: true

class MetadataEntitySync
  FIELDS = {
    'Movie' => { director: 'Director', writer: 'Writer', actors: 'Actor', genre: 'Genre' },
    'TvShow' => { director: 'Director', writer: 'Writer', actors: 'Actor', network: 'Network', genre: 'Genre' },
    'Album' => { artist: 'Album artist', genre: 'Genre' },
    'Comic' => { writer: 'Writer', artist: 'Artist', publisher: 'Publisher' },
    'Book' => { author: 'Author', publisher: 'Publisher' },
    'VideoGame' => { developer: 'Developer', publisher: 'Publisher', platform: 'Platform' }
  }.freeze
  KINDS = { 'Genre' => 'genre', 'Platform' => 'platform', 'Network' => 'organization',
            'Publisher' => 'organization', 'Developer' => 'organization', 'Album artist' => 'artist' }.freeze

  def self.without_corrected_roles(item, credits, fields, detail_fields = [])
    roles = FIELDS.fetch(item.class.name, {}).slice(*fields.map(&:to_sym)).values
    roles << 'Genre' if item.is_a?(VideoGame) && detail_fields.include?('genres')
    credits.reject { |credit| roles.include?(credit['role']) }
  end

  def self.call(item)
    item.class.transaction do
      rows = structured(item)
      synchronize(item, rows, 'provider')
      synchronize(item, legacy(item, rows), 'legacy')
    end
  end

  def self.structured(item)
    rows = item.respond_to?(:metadata_credits_data) ? item.metadata_credits_data : item.credits
    Array(rows).flat_map do |row|
      next [] unless row.is_a?(Hash) && row['name'].present?

      row.fetch('role', 'Contributor').to_s.split(/,\s*/).map do |role|
        row.merge('role' => ProviderEntityMetadata::ROLES.fetch(role, role.capitalize), 'kind' => row['kind'] || 'person')
      end
    end
  end

  def self.legacy(item, structured)
    FIELDS.fetch(item.class.name, {}).flat_map do |field, role|
      known = structured.select { |row| row['role'] == role }.map { |row| MetadataEntity.normalize(row['name']) }
      raw = item.public_send(field).to_s
      next [] if known.include?(MetadataEntity.normalize(raw))

      raw.split(%r{,\s+|\s+/\s+|[;|]+}).map(&:strip).compact_blank.filter_map do |name|
        next if known.include?(MetadataEntity.normalize(name))

        { 'name' => name, 'role' => role, 'kind' => KINDS.fetch(role, 'person') }
      end
    end + genres(item)
  end

  def self.genres(item)
    return [] unless item.is_a?(VideoGame)

    Array(item.metadata_details['genres']).map { |name| { 'name' => name, 'role' => 'Genre', 'kind' => 'genre' } }
  end

  def self.synchronize(item, rows, source)
    retained = rows.each_with_index.map do |row, position|
      entity = MetadataEntityResolver.call(row)
      credit = item.metadata_credits.find_or_initialize_by(metadata_entity: entity, role: row['role'], source: source)
      credit.assign_attributes(position: position, details: row.slice('character', 'credited_as', 'instrument'))
      credit.save! if credit.changed?
      credit.id
    end
    item.metadata_credits.where(source: source).where.not(id: retained).destroy_all
    item.metadata_credits.reset
  end
end
