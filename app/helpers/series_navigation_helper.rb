# frozen_string_literal: true

require 'uri'

module SeriesNavigationHelper
  def source_link_or_text(value)
    url = URI.parse(value.to_s)
    return value unless %w[http https].include?(url.scheme) && url.host.present? && url.userinfo.nil?

    link_to(value, url.to_s, rel: 'noopener noreferrer')
  rescue URI::InvalidURIError
    value
  end

  def media_release_date(item)
    value = item.is_a?(TvEpisode) ? item.air_date : item.release_date
    return value if value.is_a?(Date)
    return nil unless value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    Date.iso8601(value)
  rescue ArgumentError
    nil
  end

  def comic_issue_label(issue)
    [issue.issue_number.present? ? "##{issue.issue_number}" : nil, issue.title.presence].compact.join(': ')
                                                                                        .presence || 'Unnumbered issue'
  end

  def series_return_path(item, parent)
    options = { anchor: 'series-entries' }
    options[:season] = item.season if item.is_a?(TvEpisode)
    polymorphic_path(parent, options)
  end
end
