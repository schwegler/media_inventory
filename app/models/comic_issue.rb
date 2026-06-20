# frozen_string_literal: true

class ComicIssue < ApplicationRecord
  belongs_to :comic
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  def display_title
    issue_str = issue_number.present? ? " ##{issue_number}" : ''
    title_str = title.present? ? ": #{title}" : ''
    "#{comic&.title}#{issue_str}#{title_str}"
  end

  # rubocop:disable Naming/PredicatePrefix
  def is_collected?
    comic&.is_collected? || false
  end
  # rubocop:enable Naming/PredicatePrefix

  def in_watchlist?
    false
  end

  def consumed?
    read?
  end

  def consumed_at
    read_at
  end

  # Dirty tracking helper methods to prevent NoMethodErrors from Trackable concern
  def saved_change_to_consumed?
    saved_change_to_read?
  end

  def saved_change_to_consumed
    saved_change_to_read
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
