# frozen_string_literal: true

class BookChapterCompletion < ApplicationRecord
  belongs_to :book_reading_pass
  belongs_to :book_chapter
  validates :book_chapter_id, uniqueness: { scope: :book_reading_pass_id }
  validate do
    next if book_reading_pass&.book_edition_id == book_chapter&.book_edition_id

    errors.add(:book_chapter, 'must belong to the selected edition')
  end
end
