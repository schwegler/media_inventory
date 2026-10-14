# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
# Manages ConsumptionPass lifecycle for TV shows and comics.
#
# Episode/issue LibraryItems keep meaning "consumed at least once" (so stats, activity and
# ratings are unaffected); passes track what has been done in each individual run.
class ConsumptionPasses
  class << self
    # Record that +child+ (TvEpisode/ComicIssue) was completed by +user+ in the current pass.
    def record(user, child)
      series_lib = series_library_item(user, child)
      return unless series_lib

      pass = series_lib.consumption_passes.active.first || series_lib.consumption_passes.recent_first.first
      # A completed pass that already covers this item stays as history; re-doing it needs an explicit new pass.
      return pass if pass&.completed? && pass.entries.exists?(item: child)

      pass ||= start(series_lib)
      return unless pass

      reopen(pass) unless pass.active?
      pass.entries.find_or_create_by!(item: child) { |entry| entry.consumed_at = Time.current }
      pass.touch
      sync_completion(pass, series_lib)
      pass
    end

    # Remove +child+ from the current pass (e.g. the user hit "Undo").
    def unrecord(user, child)
      series_lib = series_library_item(user, child)
      return unless series_lib

      pass = series_lib.consumption_passes.active.first || series_lib.consumption_passes.recent_first.first
      return unless pass

      pass.entries.where(item: child).delete_all
      reopen(pass) if pass.completed?
    end

    # Drop +child+ from every pass, used when the child library item is removed.
    def forget(user, child)
      series_lib = series_library_item(user, child)
      return unless series_lib

      ConsumptionPassEntry.where(consumption_pass_id: series_lib.consumption_passes.select(:id), item: child).delete_all
    end

    # Starting a re-watch / re-read: a fresh pass. No-op if one is already active.
    def start(series_lib)
      series_lib.with_lock do
        existing = series_lib.consumption_passes.active.first
        next existing if existing

        number = (series_lib.consumption_passes.maximum(:number) || 0) + 1
        series_lib.consumption_passes.create!(number: number, status: 'active', started_on: Date.current)
      end
    end

    # Take the series off the In progress tracker while keeping its progress.
    def dismiss(pass)
      pass.update!(status: 'dismissed') if pass.active?
      pass
    end

    # Put the most recent unfinished pass back on the tracker.
    def resume(series_lib)
      return series_lib.consumption_passes.active.first if series_lib.consumption_passes.active.exists?

      pass = series_lib.consumption_passes.recent_first.first
      return unless pass&.dismissed?

      reopen(pass)
      pass
    end

    # When undoing in a re-watch, the episode must stay "watched" overall because an earlier
    # pass still covers it.
    def preserve_history?(user, child)
      series_lib = series_library_item(user, child)
      return false unless series_lib

      pass = current_pass(series_lib)
      pass.present? && pass.rewatch?
    end

    # Saves +attrs+ on the child's +library_item+ with pass semantics: ticking an item records
    # it in the current pass (even if it was already watched in an earlier one), while undoing
    # during a re-watch only removes it from that pass and leaves the lifetime flag intact.
    def apply(user, child, library_item, attrs) # rubocop:disable Naming/PredicateMethod
      consumed = attrs.key?(:consumed) ? ActiveModel::Type::Boolean.new.cast(attrs[:consumed]) : nil
      undo_in_rewatch = consumed == false && preserve_history?(user, child)
      attrs = attrs.except(:consumed, :consumed_at) if undo_in_rewatch
      return false unless library_item.update(attrs)

      if undo_in_rewatch
        unrecord(user, child)
      elsif consumed
        record(user, child)
      end
      true
    end

    def active_pass(series_lib)
      return nil unless series_lib

      series_lib.consumption_passes.active.first
    end

    def current_pass(series_lib)
      return nil unless series_lib

      series_lib.consumption_passes.active.first ||
        series_lib.consumption_passes.recent_first.first&.then { |p| p if p.dismissed? }
    end

    def pass_entry_ids(pass)
      return Set.new unless pass

      pass.entries.pluck(:item_id).to_set
    end

    def consumed?(child, user:, **options)
      return false unless user

      # Explicit nils from preloaded collections mean "absent", not "query again".
      series_lib = options.fetch(:series_lib) { series_library_item(user, child) }
      return false unless series_lib

      pass = options.fetch(:pass) { current_pass(series_lib) }
      if pass&.rewatch?
        entry_ids = options[:entry_ids] || pass_entry_ids(pass)
        entry_ids.include?(child.id)
      else
        child_lib = options.fetch(:child_lib) { user.library_items.find_by(item: child) }
        child_lib&.consumed? || false
      end
    end

    private

    def series_of(child)
      child.is_a?(TvEpisode) ? child.tv_show : child.comic
    end

    def series_library_item(user, child)
      series = series_of(child)
      series && user.library_items.find_by(item: series)
    end

    def reopen(pass)
      pass.update!(status: 'active', completed_on: nil)
    end

    def sync_completion(pass, series_lib)
      total = series_total(series_lib)
      return unless total.positive? && pass.entries.count >= total

      pass.update!(status: 'completed', completed_on: Date.current)
    end

    def series_total(series_lib)
      series = series_lib.item
      series.is_a?(TvShow) ? series.tv_episodes.count : series.comic_issues.count
    end
  end
end
# rubocop:enable Metrics/ClassLength
