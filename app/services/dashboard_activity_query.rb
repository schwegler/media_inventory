# frozen_string_literal: true

# Resolve LibraryItem proxies in SQL before ranking/limiting. Repeated lifecycle
# events never require an application-side scan through the full activity log.
class DashboardActivityQuery
  MODELS = [Movie, TvShow, Album, Comic, Book, VideoGame, TvEpisode, ComicIssue, AlbumTrack].freeze
  TYPE_SQL = "CASE WHEN activities.trackable_type = 'LibraryItem' THEN activity_library.item_type " \
             'ELSE activities.trackable_type END'
  ID_SQL = "CASE WHEN activities.trackable_type = 'LibraryItem' THEN activity_library.item_id " \
           'ELSE activities.trackable_id END'
  JOIN_SQL = "LEFT JOIN library_items activity_library ON activities.trackable_type = 'LibraryItem' " \
             'AND activity_library.id = activities.trackable_id'

  def initialize(scope, viewer_id: nil)
    @scope = scope
    @viewer_id = viewer_id
  end

  def visible(reviews_only: false)
    # Only a matching owner's public (or viewer-owned) LibraryItem grants review
    # visibility. Direct catalog trackables do not bypass that boundary.
    sql = <<~SQL.squish
      EXISTS (SELECT 1 FROM library_items review_entry
        WHERE review_entry.user_id = activities.user_id
        AND (review_entry.is_public = ? OR review_entry.user_id = ?)
        AND ((activities.trackable_type = 'LibraryItem' AND review_entry.id = activities.trackable_id)
          OR (review_entry.item_type = activities.trackable_type AND review_entry.item_id = activities.trackable_id))
        AND TRIM(COALESCE(review_entry.review, '')) <> '')
    SQL
    if reviews_only
      @scope.where(activity_type: 'reviewed').where(sql, true, @viewer_id)
    else
      @scope.where("activities.activity_type <> 'reviewed' OR #{sql}", true, @viewer_id)
    end
  end

  def latest(limit:, reviews_only: false)
    scope = identities(visible(reviews_only: reviews_only))
    ranking = "ROW_NUMBER() OVER (PARTITION BY activities.user_id, #{TYPE_SQL}, #{ID_SQL} " \
              'ORDER BY activities.created_at DESC, activities.id DESC) AS dashboard_rank'
    ranked = scope.reorder(nil).select('activities.*', Arel.sql(ranking))
    Activity.from(ranked, :activities).where(dashboard_rank: 1).order(created_at: :desc, id: :desc).limit(limit)
  end

  def popular(limit:)
    identities(visible).reorder(nil).group(Arel.sql(TYPE_SQL), Arel.sql(ID_SQL))
                       .order(Arel.sql('COUNT(*) DESC'), Arel.sql(TYPE_SQL), Arel.sql(ID_SQL)).limit(limit).count
  end

  # Batch resolves LibraryItem proxies for direct activity feed items without constructing
  # N separate query objects or chaining N nested .or conditions.
  def self.attach_review_entries(activities, viewer_id: nil)
    direct = activities.reject { |activity| activity.trackable_type == 'LibraryItem' }
    return activities if direct.empty?

    entries = build_review_entry_index(direct, viewer_id: viewer_id)
    direct.each do |activity|
      entry = entries[[activity.user_id, activity.trackable_type, activity.trackable_id]]
      activity.association(:trackable).target = entry if entry
    end
    activities
  end

  def self.build_review_entry_index(direct, viewer_id:)
    scope = review_entries_scope(direct, viewer_id: viewer_id)
    return {} unless scope

    ids = scope.group(:user_id, :item_type, :item_id).select('MIN(id)')
    LibraryItem.where(id: ids).includes(:item).index_by do |entry|
      [entry.user_id, entry.item_type, entry.item_id]
    end
  end

  def self.review_entries_scope(direct, viewer_id:)
    reviewed, other = direct.partition { |activity| activity.activity_type == 'reviewed' }
    scopes = []
    scopes << scope_for_activities(other) if other.any?
    scopes << scope_for_reviewed_activities(reviewed, viewer_id) if reviewed.any?
    scopes.compact.reduce(&:or)
  end

  def self.scope_for_activities(activities)
    tuples = activities.map { |a| [a.user_id, a.trackable_type, a.trackable_id] }.uniq
    return LibraryItem.none if tuples.empty?

    conn = ApplicationRecord.connection
    sql = tuples.map do |u_id, type, id|
      "(user_id = #{conn.quote(u_id)} AND item_type = #{conn.quote(type)} AND item_id = #{conn.quote(id)})"
    end.join(' OR ')

    LibraryItem.where(Arel.sql(sql))
  end

  def self.scope_for_reviewed_activities(activities, viewer_id)
    scope_for_activities(activities)
      .where('is_public = ? OR user_id = ?', true, viewer_id)
      .where("TRIM(COALESCE(review, '')) <> ''")
  end

  private

  def identities(scope)
    connection = ApplicationRecord.connection
    conditions = MODELS.map do |model|
      "(#{TYPE_SQL} = #{connection.quote(model.name)} AND EXISTS " \
        "(SELECT 1 FROM #{model.quoted_table_name} WHERE id = #{ID_SQL}))"
    end.join(' OR ')
    scope.joins(JOIN_SQL).where(Arel.sql(conditions))
  end
end
