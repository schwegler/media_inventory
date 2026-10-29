# frozen_string_literal: true

# Counts and candidates remain in SQL; a long-running series never loads every child.
class NextSeriesEntry
  attr_reader :children, :entries

  def initialize(series, pass)
    @tv = series.is_a?(TvShow)
    @children = @tv ? series.tv_episodes.watch_through : series.comic_issues
    @entries = pass.entries.where(item_type: @tv ? 'TvEpisode' : 'ComicIssue', item_id: @children.select(:id))
    @date = @tv ? :air_date : :release_date
  end

  def completed
    children.where(id: @entries.select(:item_id))
  end

  def next_item
    pending = children.where.not(id: @entries.select(:item_id))
    # Prefer dated, available releases, then unknown dates, then upcoming releases.
    candidates = pending.where.not(@date => [nil, '']).where(@date => ..Date.current.iso8601)
    candidates = pending.where(@date => [nil, '']) unless candidates.exists?
    candidates = pending unless candidates.exists?
    last = children.find_by(id: @entries.where(item_id: children.select(:id))
                                        .order(consumed_at: :desc, id: :desc).pick(:item_id))
    ordered = candidates.order(Arel.sql(@tv ? tv_order : comic_order))
    (after(ordered, last).first if last) || ordered.first
  end

  private

  def tv_order = 'COALESCE(season, 0), COALESCE(episode, 0), id'
  def comic_order = 'CASE WHEN issue_number IS NULL THEN 1 ELSE 0 END, issue_number, id'

  def after(scope, last)
    if @tv
      scope.where('COALESCE(season, 0) > :season OR (COALESCE(season, 0) = :season AND ' \
                  '(COALESCE(episode, 0) > :episode OR (COALESCE(episode, 0) = :episode AND id > :id)))',
                  season: last.season || 0, episode: last.episode || 0, id: last.id)
    elsif last.issue_number
      scope.where('issue_number > :number OR issue_number IS NULL OR (issue_number = :number AND id > :id)',
                  number: last.issue_number, id: last.id)
    else
      scope.where(issue_number: nil).where('id > ?', last.id)
    end
  end
end
