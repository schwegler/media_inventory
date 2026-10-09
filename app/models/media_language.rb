# frozen_string_literal: true

# Presentation terms shared by forms, activity feeds, and plain-text descriptions.
module MediaLanguage
  WATCH = { past: 'watched', negative: 'unwatched', list: 'watchlist' }.freeze
  READ = { past: 'read', negative: 'unread', list: 'reading list' }.freeze
  LISTEN = { past: 'listened to', negative: 'not listened to', list: 'listening queue' }.freeze
  PLAY = { past: 'played', negative: 'unplayed', list: 'backlog' }.freeze
  DEFAULT = { past: 'finished', negative: 'not finished', list: 'backlog' }.freeze
  TYPES = { 'Movie' => WATCH, 'TvShow' => WATCH, 'TvEpisode' => WATCH, 'WrestlingEvent' => WATCH,
            'Book' => READ, 'Comic' => READ, 'ComicIssue' => READ, 'Album' => LISTEN, 'VideoGame' => PLAY }.freeze

  def self.for(record)
    record = record.item if record.is_a?(LibraryItem)
    TYPES.fetch(record.class.name, DEFAULT)
  end
end
