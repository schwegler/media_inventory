# frozen_string_literal: true

class FavoriteShelf < ApplicationRecord
  CATEGORIES = { 'overall' => 'Overall', 'Movie' => 'Movies', 'TvShow' => 'TV shows',
                 'Album' => 'Albums', 'Comic' => 'Comics', 'Book' => 'Books', 'VideoGame' => 'Games' }.freeze
  belongs_to :user
  validates :category, inclusion: { in: CATEGORIES.keys }, uniqueness: { scope: :user_id }
  validate :valid_picks

  def items
    valid = Array(picks).select { |pick| CATEGORIES.key?(pick['type']) && pick['type'] != 'overall' }
    records = valid.group_by { |pick| pick['type'] }.transform_values do |group|
      group.first['type'].constantize.where(id: group.map { |pick| pick['id'] })
           .with_attached_cover_image.index_by(&:id)
    end
    valid.filter_map { |pick| records[pick['type']][pick['id'].to_i] }
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
