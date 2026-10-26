# frozen_string_literal: true

module ReviewExcerptsHelper
  def review_summary(entry, item: nil, author: nil, compact: false, permalink: false)
    return unless review_page_linkable?(entry)

    excerpt = ReviewExcerpt.new(entry.review, **(compact ? { length: 220, paragraphs: 2, breaks: 3 } : {}))
    author ||= current_user&.id == entry.user_id ? current_user : entry.user
    render 'shared/review_excerpt', entry: entry, item: item || entry.item, author: author, excerpt: excerpt,
                                    permalink: permalink
  end

  def review_page_linkable?(entry)
    entry.is_a?(LibraryItem) && entry.review.present? &&
      ReviewsController::REVIEWABLE_MODELS.key?(entry.item_type) &&
      (entry.is_public? || current_user&.id == entry.user_id)
  end
end
