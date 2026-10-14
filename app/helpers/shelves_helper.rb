# frozen_string_literal: true

module ShelvesHelper
  def shelf_pick_data(items)
    items.map do |item|
      { id: item.id, type: item.class.name, title: item.title, cover: item.stored_cover_url }
    end
  end
end
