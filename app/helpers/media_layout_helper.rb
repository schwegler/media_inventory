# frozen_string_literal: true

module MediaLayoutHelper
  CATALOGS = {
    'Movie' => ['Movies', 'Movie', '🎬'],
    'TvShow' => ['TV Shows', 'TV Show', '📺'],
    'Book' => ['Books', 'Book', '📘'],
    'Album' => ['Albums', 'Album', '💿'],
    'Comic' => ['Comics', 'Comic', '📚'],
    'VideoGame' => ['Video Games', 'Video Game', '🎮']
  }.freeze
  METADATA = {
    'Movie' => { director: 'Director', release_year: 'Year' },
    'TvShow' => { network: 'Network' },
    'Book' => { author: 'Author', publisher: 'Publisher', release_year: 'Year' },
    'Album' => { artist: 'Artist', genre: 'Genre', release_year: 'Year' },
    'Comic' => { writer: 'Writer', artist: 'Artist', publisher: 'Publisher', issue_number: 'Issue' },
    'VideoGame' => { developer: 'Developer', publisher: 'Publisher', platform: 'Platform', release_year: 'Year' }
  }.freeze

  def media_catalog(item_or_class)
    name = item_or_class.is_a?(Class) ? item_or_class.name : item_or_class.class.name
    CATALOGS.fetch(name)
  end

  def media_metadata(item)
    METADATA.fetch(item.class.name).filter_map do |attribute, label|
      value = item.public_send(attribute)
      [label, value] if value.present?
    end
  end

  def media_audience(item)
    { 'Album' => 'Listeners', 'Book' => 'Readers', 'Comic' => 'Readers', 'ComicIssue' => 'Readers',
      'VideoGame' => 'Players' }
      .fetch(item.class.name, 'Watchers')
  end
end
