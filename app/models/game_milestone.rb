# frozen_string_literal: true

# User-defined goals are not platform achievements and carry no fabricated rarity.
class GameMilestone < ApplicationRecord
  belongs_to :library_item
  belongs_to :game_playthrough, optional: true
  validates :title, presence: true, length: { maximum: 200 }
  validates :description, length: { maximum: 10_000 }
  validate :valid_library

  private

  def valid_library
    errors.add(:library_item, 'must be a video game') unless library_item&.item_type == 'VideoGame'
    return unless game_playthrough && game_playthrough.library_item_id != library_item_id

    errors.add(:game_playthrough, 'must belong to this game in your library')
  end
end
