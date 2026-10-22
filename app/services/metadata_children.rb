# frozen_string_literal: true

# Reconcile in place: never delete children or touch personal/social attributes.
# Explicit episode-only recovery omits artwork, enrichment and completion propagation.
class MetadataChildren
  def self.episodes(show, rows, episode_only: false)
    changed = 0
    show.with_lock do
      rows.each do |row|
        next unless row.is_a?(Hash) && row['season'].is_a?(Integer) && row['number'].is_a?(Integer)

        episode = show.tv_episodes.find_or_initialize_by(season: row['season'], episode: row['number'])
        episode.name = row['name'] if episode.name.blank?
        assign_episode_details(episode, row, show)
        image = MetadataProvider.image(row.dig('image', 'original') || row.dig('image', 'medium')) unless episode_only
        episode.assign_attributes({ air_date: row['airdate'], summary: row['summary'],
                                    thumbnail_url: image }.compact_blank)
        if episode.changed?
          episode.save!
          changed += 1
        end
        enqueue_episode_details(episode, show) unless episode_only
      end
    end
    if changed.positive? && !episode_only
      LibraryItem.where(item: show, consumed: true).find_each(&:mark_all_episodes_watched)
    end
    changed
  end

  def self.issues(comic, rows)
    changed = 0
    comic.with_lock do
      rows.each do |row|
        next unless row.is_a?(Hash) && row['id'].present? && row['issue_number'].to_s.match?(/\A\d+\z/)

        issue = comic.comic_issues.find_by(provider_id: row['id'].to_s) ||
                comic.comic_issues.find_or_initialize_by(issue_number: row['issue_number'].to_i)
        issue.provider_id = row['id'].to_s
        assign_details(issue, ChildMetadata.comic(row))
        issue.title = row['name'] if issue.title.blank?
        issue.assign_attributes({ release_date: row['cover_date'], summary: row['description'] || row['deck'],
                                  thumbnail_url: MetadataProvider.image(row.dig('image', 'original_url')) }.compact_blank)
        if issue.changed?
          issue.save!
          changed += 1
        end
        RefreshChildMetadataJob.perform_later(issue, revalidate: comic.refreshing_metadata == true)
      end
    end
    changed
  end

  def self.assign_episode_details(episode, row, show)
    episode.provider_id = row['id'].to_s if row['id'].present?
    fields = ChildMetadata.episode(row, tmdb: show.api_id.to_s.start_with?('tmdb_'))
    assign_details(episode, fields)
  end

  def self.assign_details(item, fields)
    details = fields.delete(:metadata_details)
    fields[:metadata_details] = item.metadata_details.merge(details) if details.present?
    item.assign_attributes(fields)
  end

  def self.enqueue_episode_details(episode, show)
    return unless show.api_id.to_s.match?(/\A\d+\z/) && episode.provider_id.to_s.match?(/\A\d+\z/)

    RefreshChildMetadataJob.perform_later(episode, revalidate: show.refreshing_metadata == true)
  end
end
