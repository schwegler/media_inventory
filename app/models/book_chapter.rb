# frozen_string_literal: true

class BookChapter < ApplicationRecord
  belongs_to :book_edition
  has_many :library_items, as: :item, dependent: :restrict_with_error
  has_many :book_chapter_completions, dependent: :restrict_with_error
  validates :identity_key, :provenance, presence: true
  validates :identity_key, :position, uniqueness: { scope: :book_edition_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  scope :ordered, -> { order(:position, :id) }

  def title
    [label.presence, self[:title].presence].compact.join(': ').presence || "Chapter #{position + 1}"
  end

  def display_title
    title
  end

  def book
    book_edition&.book
  end
end
