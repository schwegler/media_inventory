# frozen_string_literal: true

class VideoGame < ApplicationRecord
  include ReadableCatalogUrl
  include LibraryItemFormAttributes

  attr_accessor :catalog_selection, :copy_platform, :storefront, :edition, :access_method, :ownership_status, :play_status

  include StoredMediaCover

  has_one :metadata_refresh, as: :item, dependent: :destroy
  has_one_attached :cover_image
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :edit_suggestions, as: :suggestable, dependent: :destroy
  has_many :game_external_ids, dependent: :destroy
  has_many :game_artworks, dependent: :destroy
  has_one :game_artwork_batch, dependent: :destroy
  has_many :library_items, as: :item, dependent: :destroy

  validates :title, presence: true
  validates :play_status, inclusion: { in: GamePlaythrough::STATUSES }, allow_blank: true
  validates :access_method, inclusion: { in: %w[physical digital subscription cloud] }, allow_blank: true
  validates :ownership_status, inclusion: { in: %w[owned wishlist previously_owned] }, allow_blank: true
  validates :game_type,
            inclusion: { in: %w[unknown game dlc soundtrack music bundle demo mod episode video series advertising
                                hardware] }

  after_commit :register_external_id, on: %i[create update]
  after_commit :sync_details_from_api, on: %i[create update]

  private

  def register_external_id
    match = api_id.to_s.match(/\A(steam|rawg)_(\d+)\z/)
    return unless match

    identity = GameExternalId.find_or_initialize_by(provider: match[1], external_id: match[2])
    identity.video_game = self if identity.new_record?
    identity.save!
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.warn "Game identity conflict for VideoGame##{id}"
  end

  def sync_details_from_api
    return if api_id.blank? || !saved_change_to_api_id?

    EnrichVideoGameJob.perform_later(self)
  end
end
