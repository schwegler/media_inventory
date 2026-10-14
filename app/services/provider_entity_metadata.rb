# frozen_string_literal: true

# Compact, reusable credits from structured provider responses, never raw payloads.
class ProviderEntityMetadata
  ROLES = { 'Original Music Composer' => 'Composer', 'Director of Photography' => 'Cinematographer',
            'Screenplay' => 'Screenwriter', 'Writing' => 'Writer', 'Executive Producer' => 'Executive producer',
            'album artist' => 'Album artist', 'track artist' => 'Track artist', 'guest star' => 'Guest star',
            'cover' => 'Cover artist', 'cover artist' => 'Cover artist', 'penciller' => 'Penciler',
            'pencils' => 'Penciler', 'inks' => 'Inker', 'colors' => 'Colorist', 'letters' => 'Letterer',
            'writer' => 'Writer', 'artist' => 'Artist', 'editor' => 'Editor', 'colorist' => 'Colorist',
            'letterer' => 'Letterer', 'penciler' => 'Penciler', 'inker' => 'Inker', 'author' => 'Author',
            'illustrator' => 'Illustrator', 'translator' => 'Translator', 'narrator' => 'Narrator' }.freeze

  def self.credit(row, role, provider, **options)
    return if row['name'].blank?

    kind = options.fetch(:kind, 'person')
    id = options.fetch(:id, row['id'])
    { 'name' => row['name'], 'role' => ROLES.fetch(role, role.to_s.capitalize), 'kind' => kind,
      'provider' => "#{provider}:#{%w[person artist].include?(kind) ? 'contributor' : kind}",
      'external_id' => id&.to_s, 'image' => credit_image(row, provider, options),
      'aliases' => Array(row['aliases']).filter_map { |entry| entry.is_a?(Hash) ? entry['name'] : entry },
      'character' => row['character'], 'description' => biography(row) }.compact_blank
  end

  def self.credit_image(row, provider, options)
    options[:image] || row.dig('image', 'medium') || (tmdb_image(row['profile_path']) if provider == 'TMDB')
  end

  def self.biography(row)
    value = row['biography'] || row['bio']
    value = value['value'] if value.is_a?(Hash)
    value if value.is_a?(String)
  end

  def self.tmdb(data)
    cast = Array(data.dig('credits', 'cast')).filter_map do |row|
      credit(row, 'Actor', 'TMDB', image: tmdb_image(row['profile_path']))
    end
    crew = Array(data.dig('credits', 'crew')).filter_map do |row|
      credit(row, row['job'].presence || row['department'], 'TMDB', image: tmdb_image(row['profile_path']))
    end
    creators = Array(data['created_by']).filter_map { |row| credit(row, 'Creator', 'TMDB') }
    organizations = tmdb_organizations(data)
    categories = Array(data['genres']).filter_map { |row| credit(row, 'Genre', 'TMDB', kind: 'genre') }
    collection = data['belongs_to_collection']
    categories << credit(collection, 'Collection', 'TMDB', kind: 'collection') if collection.is_a?(Hash)
    cast + crew + creators + organizations + categories.compact
  end

  def self.tmdb_organizations(data)
    %w[production_companies networks].flat_map do |field|
      role = field == 'networks' ? 'Network' : 'Production company'
      Array(data[field]).filter_map do |row|
        credit(row, role, field == 'networks' ? 'TMDB:network' : 'TMDB:company', kind: 'organization',
                                                                                 image: tmdb_image(row['logo_path']))
      end
    end
  end

  def self.tmdb_image(path)
    "https://image.tmdb.org/t/p/w185#{path}" if path.present?
  end

  def self.tvmaze(data)
    embedded = data['_embedded'] || {}
    cast = Array(embedded['cast']).filter_map do |row|
      person = row.fetch('person', {}).merge('character' => row.dig('character', 'name'))
      credit(person, 'Actor', 'TVMaze', image: person.dig('image', 'medium'))
    end
    crew = Array(embedded['crew']).filter_map { |row| credit(row['person'] || {}, row['type'], 'TVMaze') }
    networks = %w[network webChannel].filter_map do |field|
      credit(data[field], 'Network', "TVMaze:#{field}", kind: 'organization') if data[field].is_a?(Hash)
    end
    cast + crew + networks
  end

  def self.comic(people)
    Array(people).flat_map do |person|
      person.fetch('role', 'Contributor').to_s.split(/,\s*/).filter_map do |role|
        credit(person, role.downcase, 'ComicVine')
      end
    end
  end

  def self.musicbrainz(data, role)
    entries = Array(data['artist-credit']).grep(Hash)
    entries.each_with_index.filter_map do |entry, index|
      artist = entry['artist'] || entry
      kind = artist['type'] == 'Person' ? 'person' : 'artist'
      previous_join = entries[index - 1]['joinphrase'] if index.positive?
      actual_role = previous_join.to_s.match?(/feat\.?|featuring/i) ? 'Featured artist' : role
      row = credit(artist, actual_role, 'MusicBrainz', kind: kind)
      row['aliases'] = (Array(row['aliases']) + [entry['name']]).compact_blank.uniq if row
      row
    end + musicbrainz_relations(data)
  end

  def self.musicbrainz_relations(data)
    direct = Array(data['relations']).filter_map do |relation|
      artist = relation['artist']
      next unless artist.is_a?(Hash)

      credit(artist, relation['type'], 'MusicBrainz', kind: artist['type'] == 'Person' ? 'person' : 'artist')
    end
    works = Array(data['relations']).filter_map { |relation| relation['work'] }
    direct + works.flat_map { |work| musicbrainz_relations(work) }
  end
end
