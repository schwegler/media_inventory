# frozen_string_literal: true

class AlbumTrack < ApplicationRecord
  include HasMetadataEntities

  belongs_to :album
  has_many :library_items, as: :item, dependent: :restrict_with_error
  validates :title, :provider_id, presence: true

  def display_title
    title
  end
end
