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
    shelf = FavoriteShelf.new(user: user, category: 'overall', picks: picks)
    shelf.valid?
    shelf.errors[:picks].each { |message| errors.add(:picks, message) }
  end
end
