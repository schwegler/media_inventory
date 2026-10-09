# frozen_string_literal: true

class GameLibraryStatistics
  COMPLETED = %w[completed beaten fully_completed].freeze

  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @libraries = user.library_items.where(item_type: 'VideoGame')
    @copies = GameCopy.where(library_item_id: @libraries.select(:id))
    @runs = GamePlaythrough.where(library_item_id: @libraries.select(:id))
  end

  def call
    completed = game_count(@runs.where(status: COMPLETED))
    started = game_count(@runs.where.not(status: %w[backlog replay_planned]))
    { unique_games: @libraries.distinct.count(:item_id),
      owned_copies: @copies.where(ownership_status: 'owned', access_method: %w[physical digital]).count,
      subscription_access: @copies.where(ownership_status: 'owned', access_method: 'subscription').count,
      wishlist: game_count(@copies.where(ownership_status: 'wishlist')),
      backlog: game_count(@runs.where(status: 'backlog')),
      currently_playing: game_count(@runs.where(status: %w[currently_playing replaying])), completed: completed,
      completion_rate: started.positive? ? (completed * 100.0 / started).round(1) : nil,
      recorded_minutes: recorded_minutes, imported_minutes: @copies.sum(:imported_playtime_minutes),
      by_platform: @copies.where(ownership_status: 'owned').group(:platform).count,
      completed_by_year: completed_by_year }
  end

  private

  def game_count(records)
    @libraries.where(id: records.select(:library_item_id)).distinct.count(:item_id)
  end

  def recorded_minutes
    GameSession.joins(:game_playthrough).where(game_playthroughs: { library_item_id: @libraries.select(:id) })
               .sum(Arel.sql(GameSession.duration_sql)).to_f / 60
  end

  def completed_by_year
    @runs.where(status: COMPLETED).where.not(completed_on: nil).pluck(:library_item_id, :completed_on)
         .group_by { |_id, date| date.year }.transform_values { |rows| rows.map(&:first).uniq.length }
  end
end
