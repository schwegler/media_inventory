# frozen_string_literal: true

class GameSession < ApplicationRecord
  belongs_to :game_playthrough
  validates :started_at, :ended_at, presence: true
  validates :enjoyment, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
  validates :progress, numericality: { only_integer: true, in: 0..100 }, allow_nil: true
  validates :mood, length: { maximum: 80 }
  validate :valid_duration

  def self.duration_sql
    if connection.adapter_name == 'PostgreSQL'
      'EXTRACT(EPOCH FROM (game_sessions.ended_at - game_sessions.started_at))'
    else
      '(julianday(game_sessions.ended_at) - julianday(game_sessions.started_at)) * 86400.0'
    end
  end

  def duration_minutes
    ((ended_at - started_at) / 60).round(1) if started_at && ended_at
  end

  private

  def valid_duration
    return unless started_at && ended_at

    errors.add(:ended_at, 'must follow start and be within 24 hours') unless (ended_at - started_at).between?(1, 86_400)
  end
end
