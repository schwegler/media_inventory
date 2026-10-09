# frozen_string_literal: true

class GameLibraryView < ApplicationRecord
  belongs_to :user
  validates :name, presence: true, length: { maximum: 60 }, uniqueness: { scope: :user_id }
  validate :valid_filters

  private

  def valid_filters
    valid = filters.is_a?(Hash) && (filters.keys - GameLibraryQuery::FILTERS).empty? &&
            filters.values.all? { |value| value.is_a?(String) && value.length <= 200 }
    errors.add(:filters, 'must contain supported collection filters') unless valid
  end
end
