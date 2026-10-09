# frozen_string_literal: true

class GamePlaythrough < ApplicationRecord
  STATUSES = %w[backlog currently_playing paused completed beaten fully_completed dropped replay_planned replaying].freeze
  belongs_to :library_item
  has_many :game_sessions, dependent: :destroy
  validates :status, inclusion: { in: STATUSES }
  validates :progress, numericality: { only_integer: true, in: 0..100 }
  validate :valid_dates_and_game

  private

  def valid_dates_and_game
    errors.add(:library_item, 'must be a video game') unless library_item&.item_type == 'VideoGame'
    return unless started_on && completed_on && completed_on < started_on

    errors.add(:completed_on, 'must follow the start date')
  end
end
