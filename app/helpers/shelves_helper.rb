# frozen_string_literal: true

module ShelvesHelper
  SHELF_THEMES = %w[midnight gallery electric halloween telly facet].freeze
  SHELF_IMAGE_STYLES = { 'layout' => %w[exhibition reading collector], 'texture' => %w[clean paper stars],
                         'companion' => %w[auto none telly facet bat] }.freeze

  def shelf_navigation_path(user, theme:, style:, category: nil)
    shelf_path(user.username, **shelf_image_style(style).symbolize_keys, category: category, theme: theme)
  end

  def shelf_image_style(input)
    SHELF_IMAGE_STYLES.to_h do |key, choices|
      value = input[key]
      [key, choices.include?(value) ? value : choices.first]
    end
  end

  def shelf_preview_signature(user, category)
    shelves = user.favorite_shelves.order(:category)
    shelves = shelves.where(category: category) unless category == 'overview'
    payload = ['shelf-image-v2', user.username, user.shelf_headline, shelves.pluck(:category, :picks)]
    Digest::SHA256.hexdigest(payload.to_json)
  end

  def shelf_preview_image(user, category, theme, style: shelf_image_style({}))
    signature = shelf_preview_signature(user, category)
    user.shelf_previews.find do |image|
      image.blob.metadata.values_at('category', 'theme', 'signature') == [category, theme, signature] &&
        shelf_image_style(image.blob.metadata.fetch('style', {})) == style
    end
  end

  def shelf_pick_data(items)
    items.map do |item|
      { id: item.id, type: item.class.name, title: item.title, cover: item.stored_cover_url, url: polymorphic_path(item) }
    end
  end
end
