# frozen_string_literal: true

module ActivitiesHelper
  def activity_link_description(activity)
    user_link = link_to(activity.user.name, activity.user, class: 'activity-user-link')
    trackable = activity.trackable

    if trackable.nil?
      return "#{user_link} performed an action on a deleted item".html_safe
    end

    trackable_link = link_to(trackable.title, trackable, class: 'activity-item-link')

    case activity.activity_type
    when 'added'
      case activity.trackable_type
      when 'Movie'
        "#{user_link} added movie '#{trackable_link}' to their collection"
      when 'Album'
        artist = trackable.artist.present? ? html_escape(trackable.artist) : 'unknown artist'
        "#{user_link} added #{artist}'s '#{trackable_link}' to their album collection"
      when 'Comic'
        issue = trackable.issue_number.present? ? " ##{trackable.issue_number}" : ''
        "#{user_link} added issue#{issue} of '#{trackable_link}' to their comic collection"
      when 'TvShow'
        season = trackable.season
        episode = sprintf('%02d', trackable.episode)
        "#{user_link} added S#{season}E#{episode} of '#{trackable_link}' to their TV show progress"
      when 'WrestlingEvent'
        "#{user_link} added wrestling event '#{trackable_link}' to their collection"
      else
        "#{user_link} added '#{trackable_link}' to their collection"
      end
    when 'reviewed'
      rating_str = trackable.rating.present? ? " (Rating: #{trackable.rating} ★)" : ""
      case activity.trackable_type
      when 'Movie'
        "#{user_link} reviewed movie '#{trackable_link}'#{rating_str}"
      when 'Album'
        artist = trackable.artist.present? ? " by #{html_escape(trackable.artist)}" : ""
        "#{user_link} reviewed album '#{trackable_link}'#{artist}#{rating_str}"
      when 'Comic'
        issue = trackable.issue_number.present? ? " issue ##{trackable.issue_number}" : ''
        "#{user_link} reviewed comic '#{trackable_link}'#{issue}#{rating_str}"
      when 'TvShow'
        season = trackable.season
        episode = sprintf('%02d', trackable.episode)
        "#{user_link} reviewed S#{season}E#{episode} of '#{trackable_link}'#{rating_str}"
      when 'WrestlingEvent'
        event_date = trackable.date.present? ? " for #{trackable.date.strftime('%B %d')}" : ""
        "#{user_link} reviewed wrestling event '#{trackable_link}'#{event_date}#{rating_str}"
      else
        "#{user_link} reviewed '#{trackable_link}'#{rating_str}"
      end
    when 'watchlist'
      case activity.trackable_type
      when 'Movie'
        "#{user_link} added movie '#{trackable_link}' to their watchlist"
      when 'Album'
        artist = trackable.artist.present? ? " by #{html_escape(trackable.artist)}" : ""
        "#{user_link} added album '#{trackable_link}'#{artist} to their watchlist"
      when 'Comic'
        issue = trackable.issue_number.present? ? " issue ##{trackable.issue_number}" : ''
        "#{user_link} added comic '#{trackable_link}'#{issue} to their watchlist"
      when 'TvShow'
        "#{user_link} added TV show '#{trackable_link}' to their watchlist"
      when 'WrestlingEvent'
        "#{user_link} added wrestling event '#{trackable_link}' to their watchlist"
      else
        "#{user_link} added '#{trackable_link}' to their watchlist"
      end
    when 'consumed'
      verb = case activity.trackable_type
             when 'Movie', 'TvShow', 'WrestlingEvent' then 'watched'
             when 'Album' then 'listened to'
             when 'Comic' then 'read'
             else 'consumed'
             end
      date_str = trackable.consumed_at.present? ? " on #{trackable.consumed_at.strftime('%B %d, %Y')}" : ""
      case activity.trackable_type
      when 'Movie'
        "#{user_link} #{verb} movie '#{trackable_link}'#{date_str}"
      when 'Album'
        artist = trackable.artist.present? ? " by #{html_escape(trackable.artist)}" : ""
        "#{user_link} #{verb} album '#{trackable_link}'#{artist}#{date_str}"
      when 'Comic'
        issue = trackable.issue_number.present? ? " issue ##{trackable.issue_number}" : ''
        "#{user_link} #{verb} comic '#{trackable_link}'#{issue}#{date_str}"
      when 'TvShow'
        season = trackable.season
        episode = sprintf('%02d', trackable.episode)
        "#{user_link} #{verb} S#{season}E#{episode} of '#{trackable_link}'#{date_str}"
      when 'WrestlingEvent'
        "#{user_link} #{verb} wrestling event '#{trackable_link}'#{date_str}"
      else
        "#{user_link} #{verb} '#{trackable_link}'#{date_str}"
      end
    end.html_safe
  end
end
