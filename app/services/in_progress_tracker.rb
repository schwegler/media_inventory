# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
# Computes in-progress TV shows and Comics for a given user,
# calculating overall progress and identifying the "Next" episode or issue to consume.
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

    list = tv_show_items + comic_items
    list.sort_by { |item| item.last_consumed_at || Time.at(0) }.reverse!
    list = list.first(limit) if limit
    list
  end

  def single_item(series)
    return nil unless @user && series

    if series.is_a?(TvShow)
      single_tv_show(series)
    elsif series.is_a?(Comic)
      single_comic(series)
    end
  end

  private

  def single_tv_show(series)
    lib_item = @user.library_items.find_by(item: series)
    return nil unless lib_item

    consumed_ids = Set.new(
      @user.library_items.where(item_type: 'TvEpisode', consumed: true)
           .where(item_id: series.tv_episodes.select(:id))
           .pluck(:item_id)
    )
    build_tv_show_item(series, lib_item, consumed_ids)
  end

  def single_comic(series)
    lib_item = @user.library_items.find_by(item: series)
    return nil unless lib_item

    consumed_ids = Set.new(
      @user.library_items.where(item_type: 'ComicIssue', consumed: true)
           .where(item_id: series.comic_issues.select(:id))
           .pluck(:item_id)
    )
    build_comic_item(series, lib_item, consumed_ids)
  end

  def tv_show_items
    show_scope = @user.library_items.where(item_type: 'TvShow')
    show_scope = show_scope.where(is_public: true) if @public_only
    show_lib_items = show_scope.includes(item: [{ cover_image_attachment: :blob }]).index_by(&:item_id)
    return [] if show_lib_items.empty?

    ep_lib_scope = @user.library_items.where(item_type: 'TvEpisode', consumed: true)
    consumed_eps = TvEpisode.where(id: ep_lib_scope.select(:item_id), tv_show_id: show_lib_items.keys)
                            .pluck(:id, :tv_show_id)
    return [] if consumed_eps.empty?

    consumed_ids_by_show = Hash.new { |h, k| h[k] = Set.new }
    consumed_eps.each { |ep_id, show_id| consumed_ids_by_show[show_id].add(ep_id) }

    last_consumed_at_by_show = ep_lib_scope.where(item_id: consumed_eps.map(&:first))
                                           .joins('INNER JOIN tv_episodes ON tv_episodes.id = library_items.item_id')
                                           .group('tv_episodes.tv_show_id')
                                           .maximum('library_items.updated_at')

    build_tracked_tv_shows(show_lib_items, consumed_ids_by_show, last_consumed_at_by_show)
  end

  def build_tracked_tv_shows(show_lib_items, consumed_ids_by_show, last_consumed_at_by_show)
    items = []
    consumed_ids_by_show.each do |show_id, consumed_ids|
      lib_item = show_lib_items[show_id]
      show = lib_item&.item
      next unless show

      item = build_tv_show_item(show, lib_item, consumed_ids, last_consumed_at_by_show[show_id])
      items << item if item
    end
    items
  end

  def build_tv_show_item(show, lib_item, consumed_ids, last_consumed_at = nil)
    episodes = show.tv_episodes.order(:season, :episode).to_a
    total = episodes.size
    return nil if total.zero?

    completed = consumed_ids.size
    return nil if completed.zero? || completed >= total

    consumed_eps = episodes.select { |e| consumed_ids.include?(e.id) }
    last_ep = consumed_eps.max_by { |e| [e.season || 0, e.episode || 0] }
    next_ep = find_next_episode(episodes, last_ep, consumed_ids)
    return nil unless next_ep

    last_consumed_at ||= @user.library_items.where(item_type: 'TvEpisode', item_id: consumed_ids).maximum(:updated_at)

    Item.new(
      series: show, library_item: lib_item, media_type: 'TvShow',
      total_count: total, completed_count: completed,
      percent: ((completed.to_f / total) * 100).round,
      next_item: next_ep, last_consumed_at: last_consumed_at
    )
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

  def comic_items
    comic_scope = @user.library_items.where(item_type: 'Comic')
    comic_scope = comic_scope.where(is_public: true) if @public_only
    comic_lib_items = comic_scope.includes(item: [{ cover_image_attachment: :blob }]).index_by(&:item_id)
    return [] if comic_lib_items.empty?

    iss_lib_scope = @user.library_items.where(item_type: 'ComicIssue', consumed: true)
    consumed_issues = ComicIssue.where(id: iss_lib_scope.select(:item_id), comic_id: comic_lib_items.keys)
                                .pluck(:id, :comic_id)
    return [] if consumed_issues.empty?

    consumed_ids_by_comic = Hash.new { |h, k| h[k] = Set.new }
    consumed_issues.each { |iss_id, comic_id| consumed_ids_by_comic[comic_id].add(iss_id) }

    last_consumed_at_by_comic = iss_lib_scope.where(item_id: consumed_issues.map(&:first))
                                             .joins('INNER JOIN comic_issues ON comic_issues.id = library_items.item_id')
                                             .group('comic_issues.comic_id')
                                             .maximum('library_items.updated_at')

    build_tracked_comics(comic_lib_items, consumed_ids_by_comic, last_consumed_at_by_comic)
  end

  def build_tracked_comics(comic_lib_items, consumed_ids_by_comic, last_consumed_at_by_comic)
    items = []
    consumed_ids_by_comic.each do |comic_id, consumed_ids|
      lib_item = comic_lib_items[comic_id]
      comic = lib_item&.item
      next unless comic

      item = build_comic_item(comic, lib_item, consumed_ids, last_consumed_at_by_comic[comic_id])
      items << item if item
    end
    items
  end

  def build_comic_item(comic, lib_item, consumed_ids, last_consumed_at = nil)
    issues = comic.comic_issues.order(:issue_number).to_a
    total = issues.size
    return nil if total.zero?

    completed = consumed_ids.size
    return nil if completed.zero? || completed >= total

    consumed_iss = issues.select { |i| consumed_ids.include?(i.id) }
    last_iss = consumed_iss.max_by { |i| i.issue_number || 0 }
    next_iss = find_next_issue(issues, last_iss, consumed_ids)
    return nil unless next_iss

    last_consumed_at ||= @user.library_items.where(item_type: 'ComicIssue', item_id: consumed_ids).maximum(:updated_at)

    Item.new(
      series: comic, library_item: lib_item, media_type: 'Comic',
      total_count: total, completed_count: completed,
      percent: ((completed.to_f / total) * 100).round,
      next_item: next_iss, last_consumed_at: last_consumed_at
    )
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
