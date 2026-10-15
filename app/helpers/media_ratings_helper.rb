# frozen_string_literal: true

module MediaRatingsHelper
  def item_card_ratings(item, user_library: nil)
    return { user_rating: nil, avg_rating: nil } if item.nil?

    if item.is_a?(LibraryItem)
      user_library ||= item
      item = item.item
      return { user_rating: user_library.rating.presence, avg_rating: nil } if item.nil?
    end

    matching_items, user_item = matching_and_user_items_for(item, user_library)

    user_rating = user_item&.rating.presence
    ratings = matching_items.filter_map { |li| li.rating.to_f if li.rating.present? }
    avg_rating = ratings.any? ? (ratings.sum.to_f / ratings.size).round(1) : nil

    { user_rating: user_rating, avg_rating: avg_rating }
  end

  private

  def matching_and_user_items_for(item, user_library)
    if item.respond_to?(:library_items) && item.association(:library_items).loaded?
      matching_from_loaded(item, user_library)
    else
      matching_from_query(item, user_library)
    end
  end

  def matching_from_loaded(item, user_library)
    all_items = item.library_items
    matching = if logged_in?
                 all_items.select { |li| li.is_public? || li.user_id == current_user.id }
               else
                 all_items.select(&:is_public?)
               end
    user_item = resolve_user_item(all_items, user_library)
    [matching, user_item]
  end

  def matching_from_query(item, user_library)
    query = LibraryItem.where(item: item)
    matching = if logged_in?
                 query.where('is_public = ? OR user_id = ?', true, current_user.id).to_a
               else
                 query.where(is_public: true).to_a
               end
    user_item = resolve_user_item(matching, user_library)
    [matching, user_item]
  end

  def resolve_user_item(items, user_library)
    if user_library && logged_in? && user_library.user_id == current_user.id
      user_library
    elsif logged_in?
      items.find { |li| li.user_id == current_user.id }
    end
  end
end
