# frozen_string_literal: true

# Personal predicates always start with the signed-in user's library. Copy filters
# apply to the same copy, so a Switch copy cannot satisfy a Steam storefront filter.
class GameLibraryQuery
  FILTERS = %w[q game_type platform storefront ownership_status access_method play_status release_year
               developer publisher rating sort layout genre].freeze
  COPY_FILTERS = %w[platform storefront ownership_status access_method].freeze
  SORTS = { 'title' => 'LOWER(video_games.title) ASC', 'release' => 'video_games.release_year DESC',
            'added' => 'video_games.created_at DESC' }.freeze
  PERSONAL_SORTS = { 'added' => 'library_added_at DESC', 'last_played' => 'last_played_at DESC NULLS LAST',
                     'rating' => 'personal_rating DESC NULLS LAST', 'playtime' => 'recorded_minutes DESC NULLS LAST',
                     'completed' => 'last_completed_on DESC NULLS LAST' }.freeze

  def self.normalize(values)
    values = values.to_unsafe_h if values.respond_to?(:to_unsafe_h)
    return {} unless values.is_a?(Hash)

    values.stringify_keys.slice(*FILTERS).transform_values { |value| value.is_a?(String) ? value.first(200) : '' }
                                         .compact_blank
  end

  def initialize(filters, user: nil)
    @filters = self.class.normalize(filters)
    @user = user
  end

  def call
    scope = VideoGame.with_attached_cover_image
    scope = personal_scope(scope) if @user
    scope = metadata_filters(scope)
    scope = scope.select('video_games.*', 'LOWER(video_games.title) AS sort_title')
    sorts = @user ? SORTS.merge(PERSONAL_SORTS) : SORTS
    scope.distinct.order(Arel.sql(sorts.fetch(@filters['sort'], sorts['added'])), 'video_games.id ASC')
  end

  private

  def metadata_filters(scope)
    %w[game_type release_year].each do |field|
      next if field == 'release_year' && !@filters[field].to_s.match?(/\A\d{4}\z/)

      scope = scope.where(field => @filters[field]) if @filters[field].present?
    end
    { 'q' => 'title', 'developer' => 'developer', 'publisher' => 'publisher' }.each do |filter, field|
      next if @filters[filter].blank?

      pattern = "%#{VideoGame.sanitize_sql_like(@filters[filter].downcase)}%"
      scope = scope.where("LOWER(video_games.#{field}) LIKE ?", pattern)
    end
    return scope if @filters['genre'].blank?

    scope.where(genre_predicate, @filters['genre'].downcase)
  end

  def genre_predicate
    if VideoGame.connection.adapter_name == 'PostgreSQL'
      value = "(video_games.metadata_details->'genres')::jsonb"
      array = "CASE WHEN jsonb_typeof(#{value}) = 'array' THEN #{value} ELSE '[]'::jsonb END"
      "EXISTS (SELECT 1 FROM jsonb_array_elements_text(#{array}) genre WHERE LOWER(genre) = ?)"
    else
      "EXISTS (SELECT 1 FROM json_each(video_games.metadata_details, '$.genres') WHERE LOWER(value) = ?)"
    end
  end

  def personal_scope(scope)
    libraries = @user.library_items.where(item_type: 'VideoGame')
    scope = scope.joins(:library_items).where(library_items: { id: libraries.select(:id) })
    copies = GameCopy.where(library_item_id: libraries.select(:id))
    fields = @filters.slice(*COPY_FILTERS).compact_blank
    scope = scope.where(library_items: { id: copies.where(fields).select(:library_item_id) }) if fields.present?
    scope = filter_play_status(scope, libraries)
    scope = scope.where(library_items: { rating: @filters['rating'] }) if @filters['rating'].present?
    add_activity(scope, libraries)
  end

  def filter_play_status(scope, libraries)
    return scope if @filters['play_status'].blank?

    runs = GamePlaythrough.where(library_item_id: libraries.select(:id), status: @filters['play_status'])
    scope.where(library_items: { id: runs.select(:library_item_id) })
  end

  def add_activity(scope, libraries)
    sessions = GameSession.joins(:game_playthrough).where(game_playthroughs: { library_item_id: libraries.select(:id) })
                          .group('game_playthroughs.library_item_id')
                          .select('game_playthroughs.library_item_id, MAX(game_sessions.started_at) AS last_played_at',
                                  "SUM(#{GameSession.duration_sql}) / 60.0 AS recorded_minutes")
    runs = GamePlaythrough.where(library_item_id: libraries.select(:id)).group(:library_item_id)
                          .select('library_item_id, MAX(completed_on) AS last_completed_on')
    scope.joins("LEFT JOIN (#{sessions.to_sql}) game_activity ON game_activity.library_item_id = library_items.id")
         .joins("LEFT JOIN (#{runs.to_sql}) game_completion ON game_completion.library_item_id = library_items.id")
         .select('library_items.created_at AS library_added_at', 'game_activity.last_played_at',
                 'game_activity.recorded_minutes', 'game_completion.last_completed_on',
                 "CAST(NULLIF(library_items.rating, '') AS DECIMAL) AS personal_rating")
  end
end
