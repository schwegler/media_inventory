# frozen_string_literal: true

module MediaLibraryHelper
  LIBRARIES = {
    'Movie' => { title: 'My movie library', noun: 'films', description: 'Make tonight a movie night.',
                 queue: 'Watchlist', finished: 'Watched', unfinished: 'Unwatched',
                 fields: { director: 'Director', genre: 'Genre' } },
    'TvShow' => { title: 'My TV library', noun: 'shows', description: 'Pick up where you left off.',
                  queue: 'Watchlist', finished: 'Watched', unfinished: 'Unwatched',
                  progress: 'Watching',
                  fields: { network: 'Network', genre: 'Genre' } },
    'Book' => { title: 'My book library', noun: 'books', description: 'Find your next good read.',
                queue: 'To read', finished: 'Read', unfinished: 'Unread',
                fields: { author: 'Author', publisher: 'Publisher' } },
    'Album' => { title: 'My music library', noun: 'albums', description: 'Find your next full-album listen.',
                 queue: 'To listen', finished: 'Listened', unfinished: 'Unplayed',
                 fields: { artist: 'Artist', genre: 'Genre' } },
    'Comic' => { title: 'My comic library', noun: 'series', description: 'Keep your reading runs in order.',
                 queue: 'To read', finished: 'Read', unfinished: 'Unread',
                 progress: 'Reading',
                 fields: { publisher: 'Publisher', writer: 'Writer', artist: 'Artist' } },
    'VideoGame' => { title: 'My game library', noun: 'games', description: 'Your games, your next adventure.' }
  }.freeze

  def library_config(klass)
    LIBRARIES.fetch(klass.name)
  end

  def library_link(klass, changes = {})
    filters = if klass == VideoGame
                @filters
              else
                params.permit(:q, :status, :sort, :layout, :year, :format,
                              *library_config(klass)[:fields].keys).to_h
              end
    polymorphic_path(klass, filters.merge('library' => 'mine').merge(changes.stringify_keys).compact_blank)
  end

  def library_shelves(klass)
    config = library_config(klass)
    [['All titles', ''], [config[:progress], 'progress'], [config[:queue], 'backlog'],
     [config[:finished], 'finished'], [config[:unfinished], 'unfinished'],
     ['Collection', 'collection'], ['Physical', 'physical'], ['Digital', 'digital'],
     ['Unrated', 'unrated']].reject { |label, _| label.nil? }
  end

  def library_progress(item, library)
    return unless @library_child_totals && library

    total = @library_child_totals.fetch(item.id, 0)
    return if total.zero?

    passes = library.consumption_passes
    pass = passes.find(&:active?) || passes.max_by(&:number)
    count = if pass
              @library_pass_counts.fetch(pass.id, 0)
            else
              (library.consumed? ? total : @library_child_consumed.fetch(item.id, 0))
            end
    [count.clamp(0, total), total, item.is_a?(TvShow) ? 'episodes watched' : 'issues read']
  end
end
