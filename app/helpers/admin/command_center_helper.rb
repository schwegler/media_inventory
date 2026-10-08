# frozen_string_literal: true

module Admin
  module CommandCenterHelper
    NAVIGATION = {
      'Overview' => { dashboard: 'Command Center', activities: 'Activity' },
      'Media library' => { movies: 'Movies', tv_shows: 'TV shows', tv_episodes: 'TV episodes',
                           video_games: 'Video games', books: 'Books', comics: 'Comics',
                           comic_issues: 'Comic issues', albums: 'Albums', library_items: 'Library items' },
      'Community' => { users: 'Users', comments: 'Comments', likes: 'Likes', relationships: 'Relationships' },
      'Moderation' => { edit_suggestions: 'Edit suggestions' },
      'Integrations' => { api_configurations: 'API configuration', mastodon_oauth_applications: 'Social / OAuth' }
    }.freeze

    def admin_resource_title(key = controller_name)
      NAVIGATION.values.flat_map(&:to_a).to_h[key.to_sym] || key.humanize
    end

    def admin_label(record)
      return 'Deleted record' unless record

      case record
      when ComicIssue then record.display_title
      when User then record.username.presence || record.name
      when Activity then record.description
      when LibraryItem then admin_label(record.item)
      when EditSuggestion then "Edit to #{admin_label(record.suggestable)}"
      when Comment, Like, Relationship then admin_community_label(record)
      else admin_fallback_label(record)
      end
    end

    def admin_community_label(record)
      case record
      when Comment then "#{admin_label(record.user)} commented on #{admin_label(record.commentable)}"
      when Like then "#{admin_label(record.user)} liked #{admin_label(record.likeable)}"
      when Relationship then "#{admin_label(record.follower)} follows #{admin_label(record.followed)}"
      end
    end

    def admin_fallback_label(record)
      %i[title name server source_name].filter_map { |attribute| record.try(attribute).presence }.first ||
        "#{record.class.model_name.human} ##{record.id}"
    end

    def admin_record_link(record, **)
      return 'Deleted record' unless record

      link_to(admin_label(record), [:admin, record], **)
    end

    def admin_media?(record)
      Catalog::TYPES.include?(record.class)
    end

    def admin_artwork(record)
      return url_for(record.cover_image) if record.respond_to?(:cover_image) && record.cover_image.attached?

      url = record.try(:thumbnail_url).to_s
      url if url.match?(%r{\Ahttps?://}i)
    end

    def admin_has_artwork?(record)
      record.try(:thumbnail_url).present? || (record.respond_to?(:cover_image) && record.cover_image.attached?)
    end

    def admin_provider_reference(url)
      reference = URI.parse(url.to_s)
      return unless %w[http https].include?(reference.scheme) && reference.host.present?

      link_to reference.host, reference.to_s, target: '_blank', rel: 'noopener noreferrer'
    rescue URI::InvalidURIError
      nil
    end

    def admin_media_context(record)
      %i[release_year director artist author network developer publisher].filter_map do |key|
        record.public_send(key).presence if record.respond_to?(key)
      end.first(3).join(' · ').presence || record.class.model_name.human
    end

    def admin_event_text(event)
      case event
      when Activity then event.description
      when User then "#{admin_label(event)} joined Trove"
      when Comment then "#{admin_label(event.user)} commented on #{admin_label(event.commentable)}"
      when Like then "#{admin_label(event.user)} liked #{admin_label(event.likeable)}"
      when Relationship then "#{admin_label(event.follower)} followed #{admin_label(event.followed)}"
      when EditSuggestion then "#{admin_label(event.user)} suggested an edit to #{admin_label(event.suggestable)}"
      end
    end

    def admin_changes(suggestion)
      changes = suggestion.proposed_changes
      changes = JSON.parse(changes) if changes.is_a?(String)
      changes.is_a?(Hash) ? changes : {}
    rescue JSON::ParserError
      {}
    end

    def admin_diff(current, proposed)
      before = current.to_s.split(/(\s+)/)
      after = proposed.to_s.split(/(\s+)/)
      prefix = 0
      prefix += 1 while prefix < [before.size, after.size].min && before[prefix] == after[prefix]
      suffix = 0
      suffix += 1 while suffix < [before.size, after.size].min - prefix && before[-suffix - 1] == after[-suffix - 1]
      finish = suffix.zero? ? after.size : after.size - suffix
      safe_join([after.first(prefix).join, content_tag(:mark, after[prefix...finish].join),
                 suffix.zero? ? '' : after.last(suffix).join])
    end

    def artwork_percentage(row)
      row['total'].zero? ? 0 : ((row['total'] - row['missing_artwork']) * 100.0 / row['total']).round
    end
  end
end
