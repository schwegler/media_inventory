# frozen_string_literal: true

class AlbumTrack < ApplicationRecord
  include HasMetadataEntities

  belongs_to :album
  validates :title, :provider_id, presence: true

  def display_title
    title
  end
end
