# frozen_string_literal: true

class PublicReviewFeed
  def initialize(limit:)
    @limit = limit
  end

  def self.plain_text(body)
    CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(body.to_s)).strip
  end

  def records
    # EXISTS filters remove dangling polymorphic records before limiting the result.
    scope = LibraryItem.joins(:user).where(is_public: true, item_type: ReviewsController::REVIEWABLE_MODELS.keys)
                       .where.not(review_published_at: nil).where.not(review: [nil, ''])
    scope = scope.where(media_existence_sql).order(review_published_at: :desc, id: :desc)
    result = []
    # Batches also handle whitespace/HTML-only legacy bodies without underfilling the limit.
    offset = 0
    loop do
      batch = scope.offset(offset).limit(100).preload(:user, item: { cover_image_attachment: :blob }).to_a
      ActiveRecord::Associations::Preloader.new(records: batch.map(&:item).grep(TvEpisode), associations: :tv_show).call
      ActiveRecord::Associations::Preloader.new(records: batch.map(&:item).grep(ComicIssue), associations: :comic).call
      batch.each do |entry|
        result << entry unless self.class.plain_text(entry.review).blank?
        return result if result.size == @limit
      end
      break if batch.size < 100

      offset += batch.size
    end
    result
  end

  private

  def media_existence_sql
    existence = ReviewsController::REVIEWABLE_MODELS.map do |type, model|
      parent = case type
               when 'TvEpisode' then ' AND EXISTS (SELECT 1 FROM tv_shows WHERE tv_shows.id = tv_episodes.tv_show_id)'
               when 'ComicIssue' then ' AND EXISTS (SELECT 1 FROM comics WHERE comics.id = comic_issues.comic_id)'
               else ''
               end
      "(library_items.item_type = '#{type}' AND EXISTS (SELECT 1 FROM #{model.table_name} " \
        "WHERE #{model.table_name}.id = library_items.item_id#{parent}))"
    end
    existence.join(' OR ')
  end
end
