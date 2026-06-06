# frozen_string_literal: true

class Activity < ApplicationRecord
  belongs_to :user
  belongs_to :trackable, polymorphic: true

  validates :activity_type, presence: true, inclusion: { in: %w[added reviewed watchlist consumed] }

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def description
    user_name = user&.name || 'Someone'
    item_title = trackable&.title || 'an item'

    case activity_type
    when 'added'
      case trackable_type
      when 'Movie'
        "#{user_name} added movie '#{item_title}' to their collection"
      when 'Album'
        artist = trackable.respond_to?(:artist) ? trackable.artist : 'unknown artist'
        "#{user_name} added #{artist}'s '#{item_title}' to their album collection"
      when 'Comic'
        issue = trackable.respond_to?(:issue_number) ? " ##{trackable.issue_number}" : ''
        "#{user_name} added issue#{issue} of '#{item_title}' to their comic collection"
      when 'TvShow'
        season = trackable.respond_to?(:season) ? trackable.season : 1
        episode = trackable.respond_to?(:episode) ? format('%02d', trackable.episode) : '01'
        "#{user_name} added S#{season}E#{episode} of '#{item_title}' to their TV show progress"
      when 'WrestlingEvent'
        "#{user_name} added wrestling event '#{item_title}' to their collection"
      else
        "#{user_name} added '#{item_title}' to their collection"
      end
    when 'reviewed'
      rating_str = trackable&.rating.present? ? " (Rating: #{trackable.rating})" : ''
      case trackable_type
      when 'Movie'
        "#{user_name} reviewed movie '#{item_title}'#{rating_str}"
      when 'Album'
        artist = trackable.respond_to?(:artist) ? " by #{trackable.artist}" : ''
        "#{user_name} reviewed album '#{item_title}'#{artist}#{rating_str}"
      when 'Comic'
        issue = trackable.respond_to?(:issue_number) ? " issue ##{trackable.issue_number}" : ''
        "#{user_name} reviewed comic '#{item_title}'#{issue}#{rating_str}"
      when 'TvShow'
        season = trackable.respond_to?(:season) ? trackable.season : 1
        episode = trackable.respond_to?(:episode) ? format('%02d', trackable.episode) : '01'
        "#{user_name} reviewed S#{season}E#{episode} of '#{item_title}'#{rating_str}"
      when 'WrestlingEvent'
        date_str = trackable&.date.present? ? " for #{trackable.date.strftime('%B %d, %Y')}" : ''
        "#{user_name} reviewed wrestling event '#{item_title}'#{date_str}#{rating_str}"
      else
        "#{user_name} reviewed '#{item_title}'#{rating_str}"
      end
    when 'watchlist'
      case trackable_type
      when 'Movie'
        "#{user_name} added movie '#{item_title}' to their watchlist"
      when 'Album'
        artist = trackable.respond_to?(:artist) ? " by #{trackable.artist}" : ''
        "#{user_name} added album '#{item_title}'#{artist} to their watchlist"
      when 'Comic'
        issue = trackable.respond_to?(:issue_number) ? " issue ##{trackable.issue_number}" : ''
        "#{user_name} added comic '#{item_title}'#{issue} to their watchlist"
      when 'TvShow'
        "#{user_name} added TV show '#{item_title}' to their watchlist"
      when 'WrestlingEvent'
        "#{user_name} added wrestling event '#{item_title}' to their watchlist"
      else
        "#{user_name} added '#{item_title}' to their watchlist"
      end
    when 'consumed'
      verb = case trackable_type
             when 'Movie', 'TvShow', 'WrestlingEvent' then 'watched'
             when 'Album' then 'listened to'
             when 'Comic' then 'read'
             else 'consumed'
             end
      date_str = trackable&.consumed_at.present? ? " on #{trackable.consumed_at.strftime('%B %d, %Y')}" : ''
      case trackable_type
      when 'Movie'
        "#{user_name} #{verb} movie '#{item_title}'#{date_str}"
      when 'Album'
        artist = trackable.respond_to?(:artist) ? " by #{trackable.artist}" : ''
        "#{user_name} #{verb} album '#{item_title}'#{artist}#{date_str}"
      when 'Comic'
        issue = trackable.respond_to?(:issue_number) ? " issue ##{trackable.issue_number}" : ''
        "#{user_name} #{verb} comic '#{item_title}'#{issue}#{date_str}"
      when 'TvShow'
        season = trackable.respond_to?(:season) ? trackable.season : 1
        episode = trackable.respond_to?(:episode) ? format('%02d', trackable.episode) : '01'
        "#{user_name} #{verb} S#{season}E#{episode} of '#{item_title}'#{date_str}"
      when 'WrestlingEvent'
        "#{user_name} #{verb} wrestling event '#{item_title}'#{date_str}"
      else
        "#{user_name} #{verb} '#{item_title}'#{date_str}"
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
end
