# frozen_string_literal: true

class GameJournalEntry < ApplicationRecord
  belongs_to :library_item
  validates :body, presence: true, length: { maximum: 50_000 }
  validate do
    errors.add(:library_item, 'must be a video game') unless library_item&.item_type == 'VideoGame'
  end
end
