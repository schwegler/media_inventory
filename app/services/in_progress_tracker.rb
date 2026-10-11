# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
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

    list = active_passes.filter_map { |pass| build_item(pass) }
    list.sort_by! { |item| item.last_consumed_at || Time.at(0) }
    list.reverse!
    list = list.first(limit) if limit
    list
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
                   .includes(library_item: { item: [{ cover_image_attachment: :blob }] })
  end

  def build_item(pass)
    lib_item = pass.library_item
    series = lib_item&.item
    return nil unless series

    entries = pass.entries.pluck(:item_id, :consumed_at)
    consumed_ids = entries.to_set(&:first)
    last_at = entries.map(&:last).max || pass.updated_at

    if series.is_a?(TvShow)
      build_tv_show_item(series, lib_item, pass, consumed_ids, last_at)
    else
      build_comic_item(series, lib_item, pass, consumed_ids, last_at)
    end
  end

  def build_tv_show_item(show, lib_item, pass, consumed_ids, last_consumed_at)
    episodes = show.tv_episodes.order(:season, :episode).to_a
    return nil if episodes.empty?

    done_ids = episodes.to_set(&:id) & consumed_ids
    return nil if done_ids.size >= episodes.size

    last_ep = episodes.select { |e| done_ids.include?(e.id) }.max_by { |e| [e.season || 0, e.episode || 0] }
    next_ep = find_next_episode(episodes, last_ep, done_ids)
    return nil unless next_ep

    new_item(series: show, library_item: lib_item, pass: pass, media_type: 'TvShow', total: episodes.size,
             completed: done_ids.size, next_item: next_ep, last_consumed_at: last_consumed_at)
  end

  def build_comic_item(comic, lib_item, pass, consumed_ids, last_consumed_at)
    issues = comic.comic_issues.order(:issue_number).to_a
    return nil if issues.empty?

    done_ids = issues.to_set(&:id) & consumed_ids
    return nil if done_ids.size >= issues.size

    last_iss = issues.select { |i| done_ids.include?(i.id) }.max_by { |i| i.issue_number || 0 }
    next_iss = find_next_issue(issues, last_iss, done_ids)
    return nil unless next_iss

    new_item(series: comic, library_item: lib_item, pass: pass, media_type: 'Comic', total: issues.size,
             completed: done_ids.size, next_item: next_iss, last_consumed_at: last_consumed_at)
  end

  def new_item(total:, completed:, **attrs)
    Item.new(total_count: total, completed_count: completed,
             percent: ((completed.to_f / total) * 100).round, **attrs)
  end

  def find_next_episode(episodes, last_ep, consumed_ids)
    return episodes.find { |e| !consumed_ids.include?(e.id) } unless last_ep

    episodes.find { |e| episode_comes_after?(e, last_ep) && !consumed_ids.include?(e.id) } ||
      episodes.find { |e| !consumed_ids.include?(e.id) }
  end

  def episode_comes_after?(candidate, reference)
    cand_s = candidate.season || 0
    ref_s = reference.season || 0
    return cand_s > ref_s if cand_s != ref_s

    (candidate.episode || 0) > (reference.episode || 0)
  end

  def find_next_issue(issues, last_iss, consumed_ids)
    next_iss = if last_iss
                 issues.find do |i|
                   (i.issue_number || 0) > (last_iss.issue_number || 0) &&
                     !consumed_ids.include?(i.id)
                 end
               end
    next_iss || issues.find { |i| !consumed_ids.include?(i.id) }
  end
end
# rubocop:enable Metrics/ClassLength
