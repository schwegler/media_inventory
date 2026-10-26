# frozen_string_literal: true

# Independent seasonal/anytime selections; legacy category shelves are untouched.
class ShelfCollection < ApplicationRecord
  belongs_to :user
  attr_writer :items

  before_validation :assign_slug, on: :create
  validates :title, presence: true, length: { maximum: 80 }
  validates :description, length: { maximum: 240 }
  validates :slug, uniqueness: { scope: :user_id }, format: { with: /\A[a-z0-9-]+\z/ }
  validate :valid_picks
  validate :valid_media_types
  validates :preview_length, inclusion: { in: 1..12 }

  def media_types
    allowed_media_types.presence || FavoriteShelf::CATEGORIES.keys.excluding('overall')
  end

  def preview_items
    items.first(preview_length)
  end

  def picks=(value)
    @items = nil
    super
  end

  # Memoize resolved pick items to avoid redundant database queries when accessed multiple times per request
  def items
    @items ||= FavoriteShelf.new(category: 'overall', picks: picks).items
  end

  private

  def assign_slug
    self.slug ||= "#{title.to_s.parameterize.presence || 'collection'}-#{SecureRandom.hex(3)}"
  end

  def valid_picks
    unless picks.is_a?(Array) && picks.all? { |pick| valid_identity?(pick) }
      errors.add(:picks, 'must contain existing media selections')
      return
    end
    identities = picks.map { |pick| [pick['type'], pick['id'].to_s] }
    errors.add(:picks, 'must contain unique items') if identities.uniq.size != identities.size
    picks.group_by { |pick| pick['type'] }.each { |type, group| validate_media_group(type, group) }
  end

  def valid_identity?(pick)
    return false unless pick.is_a?(Hash) && (pick['id'].is_a?(String) || pick['id'].is_a?(Integer))

    pick['id'].to_s.match?(/\A[1-9]\d*\z/)
  end

  def validate_media_group(type, group)
    unless FavoriteShelf::CATEGORIES.except('overall').key?(type)
      errors.add(:picks, 'must contain existing media selections')
      return
    end
    ids = group.map { |pick| pick['id'].to_i }
    unless type.constantize.where(id: ids).count == ids.uniq.size
      errors.add(:picks, 'must contain existing media selections')
    end
    validate_new_selections(type, group) unless media_types.include?(type)
  end

  def validate_new_selections(type, group)
    # A changed mix restricts additions; existing selections are never discarded.
    existing = Array(picks_in_database).map { |pick| [pick['type'], pick['id'].to_s] }
    return if group.all? { |pick| existing.include?([type, pick['id'].to_s]) }

    errors.add(:picks, 'must use the allowed media types for new selections')
  end

  def valid_media_types
    unless allowed_media_types.is_a?(Array) && (allowed_media_types - FavoriteShelf::CATEGORIES.keys.excluding('overall')).empty?
      errors.add(:allowed_media_types, 'must contain supported media types')
    end
  end
end
