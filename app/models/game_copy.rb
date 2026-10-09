# frozen_string_literal: true

class GameCopy < ApplicationRecord
  belongs_to :library_item
  validates :platform, presence: true
  validates :ownership_status, inclusion: { in: %w[owned wishlist previously_owned] }
  validates :access_method, inclusion: { in: %w[physical digital subscription cloud] }
  validates :purchase_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }, allow_blank: true
  validate :game_library

  private

  def game_library
    errors.add(:library_item, 'must be a video game') unless library_item&.item_type == 'VideoGame'
  end
end
