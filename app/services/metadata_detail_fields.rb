# frozen_string_literal: true

# The displayed, editable subset of provider facts; internal identifiers are excluded.
module MetadataDetailFields
  LABELS = {
    'Original title' => 'Original title', 'Languages' => 'Languages', 'Countries' => 'Production countries',
    'Runtime' => 'Runtime (minutes)', 'Overview' => 'Synopsis', 'IMDb ID' => 'IMDb ID',
    'language' => 'Language', 'status' => 'Status', 'primary-type' => 'Release type',
    'secondary-types' => 'Release categories', 'disambiguation' => 'Edition',
    'collectionExplicitness' => 'Content rating', 'copyright' => 'Copyright',
    'trackCount' => 'Tracks', 'releaseDate' => 'Release date', 'isbn_10' => 'ISBN-10', 'isbn_13' => 'ISBN-13',
    'edition_note' => 'Edition coverage', 'edition_source' => 'Edition reference',
    'number_of_pages' => 'Pages', 'edition_name' => 'Edition', 'publish_date' => 'Publication date',
    'type' => 'Type', 'start_year' => 'Series start year', 'count_of_issues' => 'Issues',
    'subjects' => 'Subjects', 'languages' => 'Languages', 'description' => 'Description',
    'original_release_date' => 'Release date', 'release_date_label' => 'Release date',
    'official_website' => 'Official website', 'genres' => 'Genres', 'features' => 'Features',
    'tags' => 'Tags', 'controller_support' => 'Controller support'
  }.freeze

  def self.normalize(proposed, current)
    raise ArgumentError unless proposed.is_a?(Hash) && (proposed.keys - LABELS.keys).empty?

    proposed.to_h { |key, value| [key, normalize_value(value, current[key])] }
  end

  def self.normalize_value(value, old)
    raise ArgumentError unless scalar?(value) || (value.is_a?(Array) && value.all? { |entry| scalar?(entry) })

    if old.is_a?(Array) && value.is_a?(String)
      value.lines.map(&:strip).compact_blank
    elsif old.is_a?(Numeric) && value.present?
      old.is_a?(Integer) ? Integer(value) : Float(value)
    else
      value
    end
  end

  def self.scalar?(value)
    value.nil? || value.is_a?(String) || value.is_a?(Numeric)
  end
end
