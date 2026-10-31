# frozen_string_literal: true

class Book < ApplicationRecord
  include HasMetadataEntities
  include ReadableCatalogUrl
  include LibraryItemFormAttributes

  include StoredMediaCover

  has_many :book_editions, dependent: :restrict_with_error

  has_one :metadata_refresh, as: :item, dependent: :destroy
  has_one_attached :cover_image
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :edit_suggestions, as: :suggestable, dependent: :destroy
  has_many :library_items, as: :item, dependent: :destroy

  validates :title, presence: true
end
