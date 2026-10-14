# frozen_string_literal: true

# Normalize only provider-owned fields; personal tracking lives outside this data.
class ChildMetadata
  def self.comic(row)
    credits = ProviderEntityMetadata.comic(row['person_credits'])
    credits += Array(row['story_arc_credits']).filter_map do |arc|
      ProviderEntityMetadata.credit(arc, 'Story arc', 'ComicVine', kind: 'collection')
    end
    details = { 'Store date' => row['store_date'], 'Characters' => names(row['character_credits']),
                'Story arcs' => names(row['story_arc_credits']), 'Teams' => names(row['team_credits']),
                'Locations' => names(row['location_credits']) }.compact_blank
    { credits: credits.presence, metadata_details: details.presence }.compact
  end

  def self.episode(row, tmdb: false)
    guests = tmdb ? row['guest_stars'] : row.dig('_embedded', 'guestcast')
    crew = tmdb ? row['crew'] : row.dig('_embedded', 'guestcrew')
    credits = guest_credits(guests, tmdb) + crew_credits(crew, tmdb)
    details = { 'Runtime' => row['runtime'].present? ? "#{row['runtime']} minutes" : nil,
                'Episode type' => row['type'], 'Production code' => row['production_code'] }.compact_blank
    { credits: credits.uniq.presence, metadata_details: details.presence }.compact
  end

  def self.guest_credits(guests, tmdb)
    Array(guests).filter_map do |person|
      name = tmdb ? person['name'] : person.dig('person', 'name')
      next if name.blank?

      row = tmdb ? person : person.fetch('person', {})
      ProviderEntityMetadata.credit(row.merge('character' => tmdb ? person['character'] : person.dig('character', 'name')),
                                    'Guest star', tmdb ? 'TMDB' : 'TVMaze')
    end
  end

  def self.crew_credits(crew, tmdb)
    Array(crew).filter_map do |person|
      name = tmdb ? person['name'] : person.dig('person', 'name')
      next if name.blank?

      ProviderEntityMetadata.credit(tmdb ? person : person.fetch('person', {}),
                                    (tmdb ? person['job'] : person['type']).presence || 'Crew',
                                    tmdb ? 'TMDB' : 'TVMaze')
    end
  end

  def self.names(rows)
    Array(rows).filter_map { |row| row['name'].presence }.uniq.join(', ').presence
  end

  def self.guest_credit(name, character)
    { 'name' => name, 'role' => 'Guest star', 'character' => character }.compact_blank
  end
end
