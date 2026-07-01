# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module ActivitiesHelper
  include ApplicationHelper

  def activity_link_description(activity)
    user_link = link_to(activity.user.name, activity.user, class: 'activity-user-link')
    trackable = activity.trackable

    return "#{user_link} performed an action on a deleted item".html_safe if trackable.nil?

    item = trackable.is_a?(LibraryItem) ? trackable.item : trackable
    item_title = item.try(:title) || item.try(:name) || 'Unknown'
    trackable_link = link_to(item_title, item, class: 'activity-item-link')

    description = case activity.activity_type
                  when 'added'
                    added_description(user_link, trackable, trackable_link)
                  when 'reviewed'
                    reviewed_description(user_link, trackable, trackable_link)
                  when 'watchlist'
                    watchlist_description(user_link, trackable, trackable_link)
                  when 'consumed'
                    consumed_description(user_link, trackable, trackable_link)
                  else
                    "#{user_link} performed an action on '#{trackable_link}'"
                  end
    description.html_safe
  end

  private

  def added_description(user_link, trackable, trackable_link)
    item = trackable.is_a?(LibraryItem) ? trackable.item : trackable
    case item.class.name
    when 'Movie'
      "#{user_link} added movie '#{trackable_link}' to their collection"
    when 'Album'
      artist = item.artist.present? ? html_escape(item.artist) : 'unknown artist'
      "#{user_link} added #{artist}'s '#{trackable_link}' to their album collection"
    when 'Comic'
      issue = item.issue_number.present? ? " ##{item.issue_number}" : ''
      "#{user_link} added issue#{issue} of '#{trackable_link}' to their comic collection"
    when 'TvShow'
      "#{user_link} added TV show '#{trackable_link}' to their collection"
    when 'TvEpisode'
      "#{user_link} added episode '#{trackable_link}' to their collection"
    when 'VideoGame'
      "#{user_link} added video game '#{trackable_link}' to their collection"
    else
      "#{user_link} added '#{trackable_link}' to their collection"
    end
  end

  def reviewed_description(user_link, trackable, trackable_link) # rubocop:disable Metrics/AbcSize
    item = trackable.is_a?(LibraryItem) ? trackable.item : trackable
    case item.class.name
    when 'Movie'
      safe_join([user_link, " reviewed movie '", trackable_link, "'", rating_safe(trackable)])
    when 'Album'
      artist_part = item.artist.present? ? [" by ", item.artist] : []
      safe_join([user_link, " reviewed album '", trackable_link, "'", *artist_part, rating_safe(trackable)])
    when 'Comic'
      issue = item.issue_number.present? ? " issue ##{item.issue_number}" : ''
      safe_join([user_link, " reviewed comic '", trackable_link, "'", issue, rating_safe(trackable)])
    when 'TvShow'
      safe_join([user_link, " reviewed TV show '", trackable_link, "'", rating_safe(trackable)])
    when 'TvEpisode'
      safe_join([user_link, " reviewed episode '", trackable_link, "'", rating_safe(trackable)])
    when 'VideoGame'
      safe_join([user_link, " reviewed video game '", trackable_link, "'", rating_safe(trackable)])
    else
      safe_join([user_link, " reviewed '", trackable_link, "'", rating_safe(trackable)])
    end
  end

  def rating_safe(trackable)
    return '' unless trackable.rating.present?

    safe_join([' (Rating: ', render_stars(trackable.rating), ')'])
  end

  def watchlist_description(user_link, trackable, trackable_link)
    item = trackable.is_a?(LibraryItem) ? trackable.item : trackable
    case item.class.name
    when 'Movie'
      "#{user_link} added movie '#{trackable_link}' to their watchlist"
    when 'Album'
      artist = item.artist.present? ? " by #{html_escape(item.artist)}" : ''
      "#{user_link} added album '#{trackable_link}'#{artist} to their watchlist"
    when 'Comic'
      issue = item.issue_number.present? ? " issue ##{item.issue_number}" : ''
      "#{user_link} added comic '#{trackable_link}'#{issue} to their watchlist"
    when 'TvShow'
      "#{user_link} added TV show '#{trackable_link}' to their watchlist"
    when 'VideoGame'
      "#{user_link} added video game '#{trackable_link}' to their backlog"
    else
      "#{user_link} added '#{trackable_link}' to their watchlist"
    end
  end

  def consumed_description(user_link, trackable, trackable_link)
    item = trackable.is_a?(LibraryItem) ? trackable.item : trackable
    verb = consumed_verb(item.class.name)
    date_str = trackable.consumed_at.present? ? " on #{trackable.consumed_at.strftime('%B %d, %Y')}" : ''
    case item.class.name
    when 'Movie'
      "#{user_link} #{verb} movie '#{trackable_link}'#{date_str}"
    when 'Album'
      artist = item.artist.present? ? " by #{html_escape(item.artist)}" : ''
      "#{user_link} #{verb} album '#{trackable_link}'#{artist}#{date_str}"
    when 'Comic'
      issue = item.issue_number.present? ? " issue ##{item.issue_number}" : ''
      "#{user_link} #{verb} comic '#{trackable_link}'#{issue}#{date_str}"
    when 'TvShow'
      "#{user_link} #{verb} TV show '#{trackable_link}'#{date_str}"
    when 'TvEpisode'
      "#{user_link} #{verb} episode '#{trackable_link}'#{date_str}"
    when 'VideoGame'
      "#{user_link} #{verb} video game '#{trackable_link}'#{date_str}"
    else
      "#{user_link} #{verb} '#{trackable_link}'#{date_str}"
    end
  end

  def consumed_verb(klass_name)
    case klass_name
    when 'Movie', 'TvShow', 'TvEpisode' then 'watched'
    when 'VideoGame' then 'played'
    when 'Album' then 'listened to'
    when 'Comic' then 'read'
    else 'consumed'
    end
  end
end
# rubocop:enable Metrics/ModuleLength
