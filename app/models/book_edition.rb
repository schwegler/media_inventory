# frozen_string_literal: true

class BookEdition < ApplicationRecord
  belongs_to :book
  has_many :book_chapters, dependent: :restrict_with_error
  has_many :book_reading_passes, dependent: :restrict_with_error
  validates :identity_key, :label, :source, presence: true
  validates :identity_key, uniqueness: { scope: :book_id }
  validates :label, :identity_key, :source_id, length: { maximum: 255 }
  validates :isbn, length: { maximum: 40 }
  validates :format, inclusion: { in: %w[print ebook audiobook unknown] }
  validates :structure_kind, inclusion: { in: %w[chapters audio_segments] }

  validate do
    errors.add(:structure_kind, 'audio segments require an audiobook edition') if
      structure_kind == 'audio_segments' && format != 'audiobook'
  end

  def display_title
    "#{label} · #{format.humanize}"
  end
end
