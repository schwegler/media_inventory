# frozen_string_literal: true

class TvEpisode < ApplicationRecord
  include Trackable

  belongs_to :tv_show

  def user
    tv_show&.user
  end

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
end
