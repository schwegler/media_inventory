# frozen_string_literal: true

module ShelvesHelper
  def shelf_preview_signature(user, category)
    shelves = user.favorite_shelves.order(:category)
    shelves = shelves.where(category: category) unless category == 'overview'
    Digest::SHA256.hexdigest([user.username, user.shelf_headline, shelves.pluck(:category, :picks)].to_json)
  end

  def shelf_preview_image(user, category, theme)
    signature = shelf_preview_signature(user, category)
    user.shelf_previews.find do |image|
      image.blob.metadata.values_at('category', 'theme', 'signature') == [category, theme, signature]
    end
  end

  def shelf_pick_data(items)
    items.map do |item|
      { id: item.id, type: item.class.name, title: item.title, cover: item.stored_cover_url, url: polymorphic_path(item) }
    end
  end
end
