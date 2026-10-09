# frozen_string_literal: true

class GameExternalId < ApplicationRecord
  belongs_to :video_game
  validates :provider, :external_id, presence: true
  validates :external_id, uniqueness: { scope: :provider }
end
