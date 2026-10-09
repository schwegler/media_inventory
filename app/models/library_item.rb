# frozen_string_literal: true

class LibraryItem < ApplicationRecord
  include Trackable

  has_one_attached :game_cover_image

  belongs_to :user
  belongs_to :item, polymorphic: true

  has_many :game_copies, dependent: :destroy
  has_many :game_playthroughs, dependent: :destroy
  has_many :game_journal_entries, dependent: :destroy

  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

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
end
