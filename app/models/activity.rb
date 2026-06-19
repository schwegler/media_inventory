# frozen_string_literal: true

class Activity < ApplicationRecord
  belongs_to :user
  belongs_to :trackable, polymorphic: true

  validates :activity_type, presence: true, inclusion: { in: %w[added reviewed watchlist consumed] }

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def description
    user_name = user&.name || 'Someone'
    media_item = trackable.is_a?(LibraryItem) ? trackable.item : trackable
    item_title = media_item.try(:title) || media_item.try(:name) || 'an item'
    type_name = media_item&.class&.name

    case activity_type
    when 'added'
      case type_name
      when 'Movie'
        "#{user_name} added movie '#{item_title}' to their collection"
      when 'Album'
        artist = media_item.respond_to?(:artist) ? media_item.artist : 'unknown artist'
        "#{user_name} added #{artist}'s '#{item_title}' to their album collection"
      when 'Comic'
        issue = media_item.respond_to?(:issue_number) ? " ##{media_item.issue_number}" : ''
        "#{user_name} added issue#{issue} of '#{item_title}' to their comic collection"
      when 'TvShow'
        "#{user_name} added TV show '#{item_title}' to their collection"
      when 'TvEpisode'
        "#{user_name} added episode '#{item_title}' to their collection"
      when 'VideoGame'
        "#{user_name} added video game '#{item_title}' to their collection"
      else
        "#{user_name} added '#{item_title}' to their collection"
      end
    when 'reviewed'
      rating_str = trackable&.rating.present? ? " (Rating: #{trackable.rating})" : ''
      case type_name
      when 'Movie'
        "#{user_name} reviewed movie '#{item_title}'#{rating_str}"
      when 'Album'
        artist = media_item.respond_to?(:artist) ? " by #{media_item.artist}" : ''
        "#{user_name} reviewed album '#{item_title}'#{artist}#{rating_str}"
      when 'Comic'
        issue = media_item.respond_to?(:issue_number) ? " issue ##{media_item.issue_number}" : ''
        "#{user_name} reviewed comic '#{item_title}'#{issue}#{rating_str}"
      when 'TvShow'
        "#{user_name} reviewed TV show '#{item_title}'#{rating_str}"
      when 'TvEpisode'
        "#{user_name} reviewed episode '#{item_title}'#{rating_str}"
      when 'VideoGame'
        "#{user_name} reviewed video game '#{item_title}'#{rating_str}"
      else
        "#{user_name} reviewed '#{item_title}'#{rating_str}"
      end
    when 'watchlist'
      case type_name
      when 'Movie'
        "#{user_name} added movie '#{item_title}' to their watchlist"
      when 'Album'
        artist = media_item.respond_to?(:artist) ? " by #{media_item.artist}" : ''
        "#{user_name} added album '#{item_title}'#{artist} to their watchlist"
      when 'Comic'
        issue = media_item.respond_to?(:issue_number) ? " issue ##{media_item.issue_number}" : ''
        "#{user_name} added comic '#{item_title}'#{issue} to their watchlist"
      when 'TvShow'
        "#{user_name} added TV show '#{item_title}' to their watchlist"
      when 'VideoGame'
        "#{user_name} added video game '#{item_title}' to their backlog"
      else
        "#{user_name} added '#{item_title}' to their watchlist"
      end
    when 'consumed'
      verb = case type_name
             when 'Movie', 'TvShow', 'TvEpisode' then 'watched'
             when 'VideoGame' then 'played'
             when 'Album' then 'listened to'
             when 'Comic' then 'read'
             else 'consumed'
             end
      date_str = trackable&.consumed_at.present? ? " on #{trackable.consumed_at.strftime('%B %d, %Y')}" : ''
      case type_name
      when 'Movie'
        "#{user_name} #{verb} movie '#{item_title}'#{date_str}"
      when 'Album'
        artist = media_item.respond_to?(:artist) ? " by #{media_item.artist}" : ''
        "#{user_name} #{verb} album '#{item_title}'#{artist}#{date_str}"
      when 'Comic'
        issue = media_item.respond_to?(:issue_number) ? " issue ##{media_item.issue_number}" : ''
        "#{user_name} #{verb} comic '#{item_title}'#{issue}#{date_str}"
      when 'TvShow'
        "#{user_name} #{verb} TV show '#{item_title}'#{date_str}"
      when 'TvEpisode'
        "#{user_name} #{verb} episode '#{item_title}'#{date_str}"
      when 'VideoGame'
        "#{user_name} #{verb} video game '#{item_title}'#{date_str}"
      else
        "#{user_name} #{verb} '#{item_title}'#{date_str}"
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
end
