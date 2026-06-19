# frozen_string_literal: true

class TvEpisode < ApplicationRecord
  include Trackable

  belongs_to :tv_show
  has_many :comments, as: :commentable, dependent: :destroy

  def title
    show_title = tv_show&.title
    "#{show_title} S#{season}E#{episode}: #{name}"
  end

  # rubocop:disable Naming/PredicatePrefix
  def is_collected?
    tv_show&.is_collected? || false
  end
  # rubocop:enable Naming/PredicatePrefix

  def in_watchlist?
    false
  end

  def consumed?
    watched?
  end

  def consumed_at
    watched_at
  end

  # Dirty tracking helper methods to prevent NoMethodErrors from Trackable concern
  def saved_change_to_consumed?
    saved_change_to_watched?
  end

  def saved_change_to_consumed
    saved_change_to_watched
  end

  def saved_change_to_is_collected?
    false
  end

  def saved_change_to_is_collected
    nil
  end

  def saved_change_to_in_watchlist?
    false
  end

  def saved_change_to_in_watchlist
    nil
  end
end
