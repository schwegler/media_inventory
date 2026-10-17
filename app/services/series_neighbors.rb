# frozen_string_literal: true

class SeriesNeighbors
  def self.call(item)
    if item.is_a?(TvEpisode)
      scope = item.tv_show.tv_episodes
      order = ['COALESCE(season, 0)', 'COALESCE(episode, 0)', 'id'].map { |sql| Arel.sql(sql) }
      values = [item.season || 0, item.episode || 0, item.id]
      before = scope.where('(COALESCE(season, 0), COALESCE(episode, 0), id) < (?, ?, ?)', *values)
      after = scope.where('(COALESCE(season, 0), COALESCE(episode, 0), id) > (?, ?, ?)', *values)
    else
      scope = item.comic.comic_issues
      order = ['CASE WHEN issue_number IS NULL THEN 1 ELSE 0 END', 'COALESCE(issue_number, 0)', 'id']
              .map { |sql| Arel.sql(sql) }
      values = [item.issue_number.nil? ? 1 : 0, item.issue_number || 0, item.id]
      before = scope.where('(CASE WHEN issue_number IS NULL THEN 1 ELSE 0 END, COALESCE(issue_number, 0), id) < (?, ?, ?)',
                           *values)
      after = scope.where('(CASE WHEN issue_number IS NULL THEN 1 ELSE 0 END, COALESCE(issue_number, 0), id) > (?, ?, ?)',
                          *values)
    end
    { previous: before.order(*order.map(&:desc)).first, next: after.order(*order).first }
  end
end
