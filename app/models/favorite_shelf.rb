# frozen_string_literal: true

class FavoriteShelf < ApplicationRecord
  CATEGORIES = { 'overall' => 'Overall', 'Movie' => 'Movies', 'TvShow' => 'TV shows',
                 'Album' => 'Albums', 'Comic' => 'Comics', 'Book' => 'Books', 'VideoGame' => 'Games' }.freeze
  belongs_to :user
  validates :category, inclusion: { in: CATEGORIES.keys }, uniqueness: { scope: :user_id }
  validate :valid_picks

  def items
    Array(picks).filter_map do |pick|
      next unless CATEGORIES.key?(pick['type']) && pick['type'] != 'overall'

      pick['type'].constantize.find_by(id: pick['id'])
    end
  end

  private

  def valid_picks
    unless picks.is_a?(Array) && picks.size <= 5 && picks.uniq.size == picks.size
      errors.add(:picks, 'must contain up to five unique items')
      return
    end
    picks.each do |pick|
      type = pick.is_a?(Hash) && pick['type']
      unless CATEGORIES.key?(type) && type != 'overall' && ['overall', type].include?(category) &&
             type.constantize.exists?(id: pick['id'])
        errors.add(:picks, 'must contain existing items of the selected media type')
      end
    end
  end
end
