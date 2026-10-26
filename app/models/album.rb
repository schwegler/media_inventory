# frozen_string_literal: true

class Album < ApplicationRecord
  include HasMetadataEntities
  include ReadableCatalogUrl
  include LibraryItemFormAttributes

  include StoredMediaCover

  has_many :album_tracks, dependent: :destroy

  has_one :metadata_refresh, as: :item, dependent: :destroy
  has_one_attached :cover_image
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :edit_suggestions, as: :suggestable, dependent: :destroy
  has_many :library_items, as: :item, dependent: :destroy
  validates :title, presence: true

  after_commit :sync_details_from_api, on: %i[create update]

  private

  def sync_details_from_api
    return if api_id.blank? || !saved_change_to_api_id?

    # Track imports must not depend on the volatile, bounded background queue or
    # the requesting user's refresh cooldown. Admin and service creation use this
    # same path. Provider failures are recorded for an explicit metadata retry.
    MetadataRefresher.new(self, nil).import_album
  end
end
