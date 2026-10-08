# frozen_string_literal: true

# Reconcile in place: never delete children or touch personal/social attributes.
class MetadataChildren
  def self.episodes(show, rows)
    changed = 0
    show.with_lock do
      rows.each do |row|
        next unless row.is_a?(Hash) && row['season'].is_a?(Integer) && row['number'].is_a?(Integer)

        episode = show.tv_episodes.find_or_initialize_by(season: row['season'], episode: row['number'])
        episode.name = row['name'] if episode.name.blank?
        image = MetadataProvider.image(row.dig('image', 'original') || row.dig('image', 'medium'))
        episode.assign_attributes({ air_date: row['airdate'], summary: row['summary'],
                                    thumbnail_url: image }.compact_blank)
        next unless episode.changed?

        episode.save!
        changed += 1
      end
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
        issue.title = row['name'] if issue.title.blank?
        issue.assign_attributes({ release_date: row['cover_date'], summary: row['description'] || row['deck'],
                                  thumbnail_url: MetadataProvider.image(row.dig('image', 'original_url')) }.compact_blank)
        next unless issue.changed?

        issue.save!
        changed += 1
      end
    end
    changed
  end
end
