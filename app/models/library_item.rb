# frozen_string_literal: true

class LibraryItem < ApplicationRecord
  include Trackable

  has_one_attached :game_cover_image

  belongs_to :user
  belongs_to :item, polymorphic: true

  has_many :game_copies, dependent: :destroy
  has_many :game_playthroughs, dependent: :destroy
  has_many :consumption_passes, dependent: :destroy
  has_many :game_journal_entries, dependent: :destroy
  has_many :game_milestones, dependent: :destroy
  has_many :game_artworks, dependent: :destroy

  validates :game_tags, length: { maximum: 20 }
  validate do
    valid = game_tags.is_a?(Array) && game_tags.all? { |tag| tag.is_a?(String) && tag.length.between?(1, 40) }
    errors.add(:game_tags, 'must contain up to 20 tags of 1–40 characters') unless valid
  end

  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  PASS_CHILD_TYPES = %w[TvEpisode ComicIssue].freeze
  after_save :record_pass_entry, if: -> { PASS_CHILD_TYPES.include?(item_type) && saved_change_to_consumed? }
  after_destroy :forget_pass_entry, if: -> { PASS_CHILD_TYPES.include?(item_type) }

  def method_missing(method, *, &)
    if item.respond_to?(method)
      item.send(method, *, &)
    else
      super
    end
  end

  def respond_to_missing?(method, include_private = false)
    item.respond_to?(method, include_private) || super
  end

  private

  def record_pass_entry
    if consumed?
      ConsumptionPasses.record(user, item)
    else
      ConsumptionPasses.unrecord(user, item)
    end
  end

  def forget_pass_entry
    ConsumptionPasses.forget(user, item)
  end
end
