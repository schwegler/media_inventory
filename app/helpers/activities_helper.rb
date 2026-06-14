# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module ActivitiesHelper
  def activity_link_description(activity)
    user_link = link_to(activity.user.name, activity.user, class: 'activity-user-link')
    trackable = activity.trackable

    return "#{user_link} performed an action on a deleted item".html_safe if trackable.nil?

    trackable_link = link_to(trackable.title, trackable, class: 'activity-item-link')

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
    case trackable.class.name
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
      episode = format('%02d', trackable.episode)
      "#{user_link} added S#{season}E#{episode} of '#{trackable_link}' to their TV show progress"
    when 'VideoGame'
      "#{user_link} added video game '#{trackable_link}' to their collection"
    else
      "#{user_link} added '#{trackable_link}' to their collection"
    end
  end

  def reviewed_description(user_link, trackable, trackable_link)
    rating_str = trackable.rating.present? ? " (Rating: #{trackable.rating} ★)" : ''
    case trackable.class.name
    when 'Movie'
      "#{user_link} reviewed movie '#{trackable_link}'#{rating_str}"
    when 'Album'
      artist = trackable.artist.present? ? " by #{html_escape(trackable.artist)}" : ''
      "#{user_link} reviewed album '#{trackable_link}'#{artist}#{rating_str}"
    when 'Comic'
      issue = trackable.issue_number.present? ? " issue ##{trackable.issue_number}" : ''
      "#{user_link} reviewed comic '#{trackable_link}'#{issue}#{rating_str}"
    when 'TvShow'
      season = trackable.season
      episode = format('%02d', trackable.episode)
      "#{user_link} reviewed S#{season}E#{episode} of '#{trackable_link}'#{rating_str}"
    when 'VideoGame'
      "#{user_link} reviewed video game '#{trackable_link}'#{rating_str}"
    else
      "#{user_link} reviewed '#{trackable_link}'#{rating_str}"
    end
  end

  def watchlist_description(user_link, trackable, trackable_link)
    case trackable.class.name
    when 'Movie'
      "#{user_link} added movie '#{trackable_link}' to their watchlist"
    when 'Album'
      artist = trackable.artist.present? ? " by #{html_escape(trackable.artist)}" : ''
      "#{user_link} added album '#{trackable_link}'#{artist} to their watchlist"
    when 'Comic'
      issue = trackable.issue_number.present? ? " issue ##{trackable.issue_number}" : ''
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
    verb = case trackable.class.name
           when 'Movie', 'TvShow' then 'watched'
           when 'VideoGame' then 'played'
           when 'Album' then 'listened to'
           when 'Comic' then 'read'
           else 'consumed'
           end
    date_str = trackable.consumed_at.present? ? " on #{trackable.consumed_at.strftime('%B %d, %Y')}" : ''
    case trackable.class.name
    when 'Movie'
      "#{user_link} #{verb} movie '#{trackable_link}'#{date_str}"
    when 'Album'
      artist = trackable.artist.present? ? " by #{html_escape(trackable.artist)}" : ''
      "#{user_link} #{verb} album '#{trackable_link}'#{artist}#{date_str}"
    when 'Comic'
      issue = trackable.issue_number.present? ? " issue ##{trackable.issue_number}" : ''
      "#{user_link} #{verb} comic '#{trackable_link}'#{issue}#{date_str}"
    when 'TvShow'
      season = trackable.season
      episode = format('%02d', trackable.episode)
      "#{user_link} #{verb} S#{season}E#{episode} of '#{trackable_link}'#{date_str}"
    when 'VideoGame'
      "#{user_link} #{verb} video game '#{trackable_link}'#{date_str}"
    else
      "#{user_link} #{verb} '#{trackable_link}'#{date_str}"
    end
  end
end
# rubocop:enable Metrics/ModuleLength
