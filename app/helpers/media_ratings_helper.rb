# frozen_string_literal: true

module MediaRatingsHelper
  def item_card_ratings(item, user_library: nil)
    return { user_rating: nil, avg_rating: nil } if item.nil?

    if item.is_a?(LibraryItem)
      user_library ||= item
      item = item.item
      return { user_rating: user_library.rating.presence, avg_rating: nil } if item.nil?
    end

    user_id = logged_in? ? current_user.id : nil
    key = MediaCardRatings.key(item, user_id)
    @preloaded_card_ratings ||= {}
    @preloaded_card_ratings.merge!(MediaCardRatings.call([item], user_id: user_id)) unless @preloaded_card_ratings.key?(key)
    ratings = @preloaded_card_ratings.fetch(key, { user_rating: nil, avg_rating: nil })
    return ratings unless user_library && user_id && user_library.user_id == user_id

    ratings.merge(user_rating: user_library.rating.presence)
  end
end
