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

  def owner_library_path
    user_path(current_user, tab: 'collection')
  end

  def owner_library_current?
    @personal_library || (current_user?(@user) && params[:preview] != 'public' &&
      %w[collection backlog].include?(params[:tab]))
  end

  def library_mode_path(klass, personal:)
    return library_link(klass) if personal

    filters = library_navigation_state.slice('q', 'sort')
    sorts = klass == VideoGame ? GameLibraryQuery::SORTS.keys : %w[newest title oldest]
    filters.delete('sort') unless sorts.include?(filters['sort'])
    filters['status'] = params[:status] if klass != VideoGame && %w[collection backlog finished].include?(params[:status])
    polymorphic_path(klass, filters.compact_blank)
  end

  # Only search, compatible sort and display settings cross format boundaries.
  # Shelf, edition and metadata filters describe the current format only.
  def library_format_path(klass)
    return request.fullpath if @personal_library && controller_name == klass.model_name.route_key

    filters = library_navigation_state.slice('q', 'layout')
    filters.delete('layout') unless %w[grid list].include?(filters['layout'])
    sort = library_navigation_state['sort'].to_s
    sort = 'newest' if sort == 'added'
    filters['sort'] = sort if %w[newest title rating].include?(sort)
    filters['sort'] = 'added' if klass == VideoGame && filters['sort'] == 'newest'
    polymorphic_path(klass, filters.merge(library: 'mine').compact_blank)
  end

  def library_navigation_state
    return @filters.slice('q', 'sort', 'layout') if controller_name == 'video_games' && @filters

    params.permit(:q, :sort, :layout).to_h
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
