class EditSuggestion < ApplicationRecord
  belongs_to :suggestable, polymorphic: true
  belongs_to :user

  validates :status, presence: true, inclusion: { in: %w[pending approved rejected] }
  validates :proposed_changes, presence: true

  after_initialize :set_default_status, if: :new_record?

  private

  def set_default_status
    self.status ||= 'pending'
  end
end
