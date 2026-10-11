# frozen_string_literal: true

require 'json'

class RefreshChildMetadataJob < ApplicationJob
  queue_as :media_imports
  discard_on ActiveJob::DeserializationError, ActiveRecord::RecordNotFound
  retry_on MediaSources::Http::Error, wait: 1.minute, attempts: 5

  def perform(item, revalidate: false)
    case item
    when ComicIssue then comic(item, revalidate)
    when TvEpisode then episode(item, revalidate)
    end
  end

  private

  def json(url, revalidate)
    JSON.parse(MediaSources::Http.cached_get(URI(url), revalidate: revalidate))
  end

  def comic(item, revalidate)
    return unless item.provider_id.to_s.match?(/\A\d+\z/)
    return unless MediaSources::Registry.enabled?('ComicVine', 'Comic')

    token = MediaSources::Registry.token('ComicVine', 'Comic')
    return if token.blank?

    query = URI.encode_www_form(api_key: token, format: 'json')
    data = json("https://comicvine.gamespot.com/api/issue/4000-#{item.provider_id}/?#{query}", revalidate)
    raise MediaSources::Http::Error, 'Issue unavailable' unless data['status_code'] == 1 && data['results'].is_a?(Hash)

    row = data['results']
    fields = ChildMetadata.comic(row).merge(summary: (row['description'] || row['deck']).presence,
                                            release_date: row['cover_date'].presence,
                                            thumbnail_url: MetadataProvider.image(row.dig('image', 'original_url')))
    fields.delete(:thumbnail_url) if item.cover_image.attached?
    apply(item, fields)
  end

  def episode(item, revalidate)
    return unless item.tv_show.api_id.to_s.match?(/\A\d+\z/) && item.provider_id.to_s.match?(/\A\d+\z/)
    return unless MediaSources::Registry.enabled?('tvmaze', 'TvShow')

    # Guest credits are episode-specific; show-level cast and crew are not substitutes.
    base = "https://api.tvmaze.com/episodes/#{item.provider_id}"
    row = { '_embedded' => { 'guestcast' => json("#{base}/guestcast", revalidate),
                             'guestcrew' => json("#{base}/guestcrew", revalidate) } }
    apply(item, ChildMetadata.episode(row))
  end

  def apply(item, fields)
    item.with_lock do
      details = fields.delete(:metadata_details)
      fields[:metadata_details] = item.metadata_details.merge(details) if details.present?
      item.update!(fields.compact)
    end
  end
end
