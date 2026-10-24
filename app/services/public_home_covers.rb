# frozen_string_literal: true

# Only existing, stored catalog artwork. Rendering never searches providers.
class PublicHomeCovers
  TYPES = [Album, Book, Movie, VideoGame, TvShow, Comic].freeze
  LIMIT = 6

  def self.call(picks)
    selected = picks.select { |item| item.cover_image.attached? }.uniq { |item| [item.class.name, item.id] }.first(LIMIT)
    return selected if selected.size == LIMIT

    batches = TYPES.map do |type|
      type.joins(:cover_image_attachment).with_attached_cover_image.order(:id).limit(LIMIT).to_a
    end
    candidates = LIMIT.times.flat_map { |index| batches.filter_map { |items| items[index] } }
    (selected + candidates).uniq { |item| [item.class.name, item.id] }.first(LIMIT)
  end
end
