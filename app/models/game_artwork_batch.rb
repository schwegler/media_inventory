# frozen_string_literal: true

class GameArtworkBatch < ApplicationRecord
  belongs_to :video_game
  validates :state, inclusion: { in: %w[idle pending processing ready unavailable failed] }
end
