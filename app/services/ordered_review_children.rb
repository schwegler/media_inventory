# frozen_string_literal: true

# Shared ordering only. Progress/completion semantics remain medium-specific.
class OrderedReviewChildren
  def self.parent(item)
    case item
    when TvEpisode then item.tv_show
    when ComicIssue then item.comic
    when AlbumTrack then item.album
    when BookChapter then item.book
    end
  end

  def self.children(item)
    case item
    when TvShow then item.tv_episodes.order(:season, :episode, :id)
    when Comic then item.comic_issues.order(Arel.sql('CASE WHEN issue_number IS NULL THEN 1 ELSE 0 END'),
                                            :issue_number, :id)
    when Album then item.album_tracks.order(Arel.sql('CASE WHEN disc_number IS NULL THEN 1 ELSE 0 END'),
                                            :disc_number, Arel.sql('CASE WHEN track_number IS NULL THEN 1 ELSE 0 END'),
                                            :track_number, :id)
    when BookEdition then item.book_chapters.ordered
    when BookChapter then item.book_edition.book_chapters.ordered
    when AlbumTrack then children(item.album)
    when TvEpisode then children(item.tv_show)
    when ComicIssue then children(item.comic)
    end
  end

  def self.visible_reviews(author, viewer)
    scope = author.library_items.where.not(review: [nil, ''])
    author == viewer ? scope : scope.where(is_public: true)
  end

  def self.reviews(item, author, viewer)
    children = children(item)
    return [] unless children

    entries = visible_reviews(author, viewer).where(item_type: children.klass.name, item_id: children.select(:id))
                                             .index_by(&:item_id)
    children.filter_map { |child| entries[child.id]&.tap { |entry| entry.item = child } }
  end
end
