# frozen_string_literal: true

# Computes in-progress TV shows and Comics for a given user,
# calculating overall progress and identifying the "Next" episode or issue to consume.
#
# A series is "in progress" while it has an active ConsumptionPass (a watch/read-through).
# Dismissing a pass takes it off the tracker without losing its progress, and starting a
# re-watch/re-read puts the series back on at 0%.
# rubocop:disable-next Metrics/ClassLength
class InProgressTracker
  Item = Struct.new(
    :series,
    :library_item,
    :media_type,
    :total_count,
    :completed_count,
    :percent,
    :next_item,
    :last_consumed_at,
    :pass,
    :playthrough,
    keyword_init: true
  ) do
    def tv_show?
      media_type == 'TvShow'
    end

    def comic?
      media_type == 'Comic'
    end

    def game?
      media_type == 'VideoGame'
    end

    def dom_id
      "in_progress_#{media_type.underscore}_#{series.id}"
    end
  end

  def self.items_for(user, **options)
    new(user, public_only: options.delete(:public_only) || false).items(**options)
  end

  def self.item_for(user, series)
    new(user).single_item(series)
  end

  def initialize(user, public_only: false)
    @user = user
    @public_only = public_only
  end

  # Entries stamp the actual watch/read action (not the user-entered completion date).
  # An untouched pass uses its immutable creation time. Editing metadata, ratings,
  # or a pass must never promote it. Ties use library ID, then run ID, descending.
  # Games use session end time and are owner-only, like the existing game workspace.
  def items(limit: nil, offset: 0, media_type: nil, sort: nil, include_games: false)
    candidates = candidates_for(media_type: media_type, include_games: include_games)
    progress = series_progress(candidates.grep(ConsumptionPass))
    candidates.select! do |record|
      record.library_item.item && (record.is_a?(GamePlaythrough) || progress.fetch(record.id).then { |t, c| t > c })
    end
    candidates.sort_by! { |record| candidate_order(record, sort, progress) }
    @total_count = candidates.size
    candidates = candidates.drop(offset)
    candidates = candidates.first(limit) if limit
    result = candidates.filter_map do |record|
      record.is_a?(GamePlaythrough) ? build_game(record) : build_item(record, progress: progress.fetch(record.id))
    end
    ActiveRecord::Associations::Preloader.new(records: result.filter_map(&:next_item),
                                              associations: { cover_image_attachment: :blob }).call
    result
  end

  attr_reader :total_count

  def single_item(series)
    return nil unless @user && series

    lib_item = @user.library_items.find_by(item: series)
    pass = lib_item && ConsumptionPass.active.find_by(library_item_id: lib_item.id)
    pass && build_item(pass)
  end

  private

  def candidates_for(media_type:, include_games:)
    return [] unless @user

    records = active_passes.to_a
    records.concat(active_games.to_a) if include_games && !@public_only
    records.select! { |record| record.library_item.item_type == media_type } if media_type.present?
    records
  end

  # Aggregate counts once per media type. Build next-entry candidates only for
  # the visible page (or two previews), never every tracked series.
  def series_progress(passes)
    result = {}
    { 'TvShow' => [TvEpisode, :tv_show_id], 'Comic' => [ComicIssue, :comic_id] }.each do |type, (model, foreign_key)|
      selected = passes.select { |pass| pass.library_item.item_type == type }
      next if selected.empty?

      children = model.where(foreign_key => selected.map { |pass| pass.library_item.item_id })
      totals = children.group(foreign_key).count
      entries = ConsumptionPassEntry.where(consumption_pass_id: selected.map(&:id), item_type: model.name)
      entry_table = ConsumptionPassEntry.arel_table
      child_table = model.arel_table
      join = entry_table.join(child_table).on(child_table[:id].eq(entry_table[:item_id])).join_sources
      completed = entries.joins(join).group(entry_table[:consumption_pass_id], child_table[foreign_key]).count
      selected.each do |pass|
        id = pass.library_item.item_id
        result[pass.id] = [totals.fetch(id, 0), completed.fetch([pass.id, id], 0)]
      end
    end
    result
  end

  def activity_at(record)
    record.class.type_for_attribute('created_at').deserialize(record.tracker_activity_at)
  end

  def candidate_order(record, sort, progress)
    title = record.library_item.item.title.downcase
    return [title, record.library_item_id, record.id] if sort == 'title'

    if sort == 'progress'
      total, completed = progress[record.id]
      percent = record.is_a?(GamePlaythrough) ? record.progress : (completed.to_f / total * 100).round
      return [-percent, title, record.library_item_id, record.id]
    end

    [-activity_at(record).to_f, -record.library_item_id, -record.id]
  end

  def active_passes
    scope = @user.library_items.where(item_type: ConsumptionPass::SERIES_TYPES)
    # TV watch progress is public independently of review/rating visibility.
    # Comics retain their existing opt-in visibility; games stay owner-only.
    scope = scope.where(item_type: 'TvShow').or(scope.where(is_public: true)) if @public_only
    activity = 'COALESCE((SELECT MAX(consumed_at) FROM consumption_pass_entries ' \
               'WHERE consumption_pass_id = consumption_passes.id), consumption_passes.created_at) AS tracker_activity_at'
    ConsumptionPass.active.where(library_item_id: scope.select(:id))
                   .select('consumption_passes.*', Arel.sql(activity))
                   .includes(library_item: { item: [{ cover_image_attachment: :blob }] })
  end

  def active_games
    scope = @user.library_items.where(item_type: 'VideoGame')
    # One preview per game: its latest run represents the current tracking state.
    activity = 'COALESCE((SELECT MAX(ended_at) FROM game_sessions WHERE ' \
               'game_playthrough_id = game_playthroughs.id), game_playthroughs.created_at) AS tracker_activity_at'
    GamePlaythrough.where(library_item_id: scope.select(:id), status: %w[currently_playing replaying])
                   .where('NOT EXISTS (SELECT 1 FROM game_playthroughs newer WHERE ' \
                          'newer.library_item_id = game_playthroughs.library_item_id AND newer.id > game_playthroughs.id)')
                   .select('game_playthroughs.*', Arel.sql(activity))
                   .includes(library_item: { item: [{ cover_image_attachment: :blob }] })
  end

  def build_game(run)
    return unless run.library_item.item

    Item.new(series: run.library_item.item, library_item: run.library_item, media_type: 'VideoGame',
             percent: run.progress, playthrough: run, last_consumed_at: activity_at(run))
  end

  def build_item(pass, progress: nil)
    lib_item = pass.library_item
    series = lib_item&.item
    return nil unless series

    selection = NextSeriesEntry.new(series, pass)
    total, completed = progress || [selection.children.count, selection.completed.count]
    return nil if total.zero? || completed >= total

    candidate = selection.next_item
    return nil unless candidate

    new_item(series: series, library_item: lib_item, pass: pass, media_type: series.class.name, total: total,
             completed: completed, next_item: candidate,
             last_consumed_at: if pass.has_attribute?(:tracker_activity_at)
                                 activity_at(pass)
                               else
                                 pass.entries.maximum(:consumed_at) || pass.created_at
                               end)
  end

  def new_item(total:, completed:, **attrs)
    Item.new(total_count: total, completed_count: completed,
             percent: ((completed.to_f / total) * 100).round, **attrs)
  end
end
