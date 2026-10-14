# frozen_string_literal: true

module MediaLayoutHelper
  CATALOGS = {
    'Movie' => %w[Movies Movie film],
    'TvShow' => ['TV Shows', 'TV Show', 'tv'],
    'Book' => %w[Books Book book],
    'Album' => %w[Albums Album disc],
    'Comic' => %w[Comics Comic library],
    'VideoGame' => ['Video Games', 'Video Game', 'gamepad']
  }.freeze

  METADATA = {
    'Movie' => { director: 'Director', writer: 'Writer', actors: 'Actors', genre: 'Genre', release_year: 'Year' },
    'TvShow' => {
      network: 'Network', director: 'Director', writer: 'Writer', actors: 'Actors', genre: 'Genre', release_year: 'Year'
    },
    'Book' => { author: 'Author', publisher: 'Publisher', release_year: 'Year' },
    'Album' => { artist: 'Artist', genre: 'Genre', release_year: 'Year' },
    'Comic' => { writer: 'Writer', artist: 'Artist', publisher: 'Publisher', issue_number: 'Issue' },
    'VideoGame' => { developer: 'Developer', publisher: 'Publisher', platform: 'Platform', release_year: 'Year' }
  }.freeze

  CATEGORY_ATTRIBUTE_MAP = {
    director: 'directors',
    writer: 'writers',
    actors: 'actors',
    platform: 'platforms',
    genre: 'genres'
  }.freeze

  def media_catalog(item_or_class)
    name = item_or_class.is_a?(Class) ? item_or_class.name : item_or_class.class.name
    CATALOGS.fetch(name)
  end

  def media_metadata(item)
    METADATA.fetch(item.class.name, {}).filter_map do |attribute, label|
      value = item.public_send(attribute) if item.respond_to?(attribute)
      [label, value, attribute] if value.present?
    end
  end

  def render_media_metadata_value(_item, attribute, value)
    category_type = CATEGORY_ATTRIBUTE_MAP[attribute&.to_sym]
    return ERB::Util.html_escape(value) unless category_type

    names = Category.split_names(value)
    return ERB::Util.html_escape(value) if names.empty?

    links = names.map do |name|
      link_to(name, category_item_path(category_type: category_type, name: name), class: 'media-category-link')
    end
    safe_join(links, ', ')
  end

  def media_audience(item)
    { 'Album' => 'Listeners', 'Book' => 'Readers', 'Comic' => 'Readers', 'ComicIssue' => 'Readers',
      'VideoGame' => 'Players' }
      .fetch(item.class.name, 'Watchers')
  end
end
