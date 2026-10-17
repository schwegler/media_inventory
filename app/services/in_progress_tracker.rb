# frozen_string_literal: true

# Computes in-progress TV shows and Comics for a given user,
# calculating overall progress and identifying the "Next" episode or issue to consume.
#
# A series is "in progress" while it has an active ConsumptionPass (a watch/read-through).
# Dismissing a pass takes it off the tracker without losing its progress, and starting a
# re-watch/re-read puts the series back on at 0%.
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
    keyword_init: true
  ) do
    def tv_show?
      media_type == 'TvShow'
    end

    def comic?
      media_type == 'Comic'
    end

    def dom_id
      "in_progress_#{media_type.underscore}_#{series.id}"
    end
  end

  def self.items_for(user, public_only: false, limit: nil)
    new(user, public_only: public_only).items(limit: limit)
  end

  def self.item_for(user, series)
    new(user).single_item(series)
  end

  def initialize(user, public_only: false)
    @user = user
    @public_only = public_only
  end

  def items(limit: nil)
    return [] unless @user

    passes = active_passes
    passes = passes.limit(limit) if limit
    passes.filter_map { |pass| build_item(pass) }
  end

  def single_item(series)
    return nil unless @user && series

    lib_item = @user.library_items.find_by(item: series)
    pass = lib_item && ConsumptionPass.active.find_by(library_item_id: lib_item.id)
    pass && build_item(pass)
  end

  private

  def active_passes
    scope = @user.library_items.where(item_type: ConsumptionPass::SERIES_TYPES)
    scope = scope.where(is_public: true) if @public_only
    ConsumptionPass.active.where(library_item_id: scope.select(:id))
                   .order(Arel.sql('COALESCE((SELECT MAX(consumed_at) FROM consumption_pass_entries ' \
                                   'WHERE consumption_pass_id = consumption_passes.id), ' \
                                   'consumption_passes.updated_at) DESC'))
                   .order(id: :desc).includes(library_item: { item: [{ cover_image_attachment: :blob }] })
  end

  def build_item(pass)
    lib_item = pass.library_item
    series = lib_item&.item
    return nil unless series

    selection = NextSeriesEntry.new(series, pass)
    total = selection.children.count
    completed = selection.completed.count
    return nil if total.zero? || completed >= total

    candidate = selection.next_item
    return nil unless candidate

    new_item(series: series, library_item: lib_item, pass: pass, media_type: series.class.name, total: total,
             completed: completed, next_item: candidate,
             last_consumed_at: pass.entries.maximum(:consumed_at) || pass.updated_at)
  end

  def new_item(total:, completed:, **attrs)
    Item.new(total_count: total, completed_count: completed,
             percent: ((completed.to_f / total) * 100).round, **attrs)
  end
end
