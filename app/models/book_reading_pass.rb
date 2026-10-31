# frozen_string_literal: true

# Book passes never mark the work finished or enter TV/comic consumption passes.
class BookReadingPass < ApplicationRecord
  belongs_to :library_item
  belongs_to :book_edition
  has_many :book_chapter_completions, dependent: :destroy
  validates :number, numericality: { only_integer: true, greater_than: 0 },
                     uniqueness: { scope: %i[library_item_id book_edition_id] }
  validate do
    errors.add(:book_edition, 'must belong to this book') unless library_item&.item == book_edition&.book
  end
end
