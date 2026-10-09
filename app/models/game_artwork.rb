# frozen_string_literal: true

class GameArtwork < ApplicationRecord
  KINDS = %w[portrait_cover landscape_cover hero background logo icon screenshot platform_box_art edition_cover].freeze
  belongs_to :video_game
  belongs_to :library_item, optional: true
  has_one_attached :image
  validates :kind, inclusion: { in: KINDS }
  validates :platform, :edition, length: { maximum: 200 }
  validate do
    if library_item && (library_item.item_type != 'VideoGame' || library_item.item_id != video_game_id)
      errors.add(:library_item, 'must reference this game')
    end
  end
end
