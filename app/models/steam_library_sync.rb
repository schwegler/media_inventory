# frozen_string_literal: true

class SteamLibrarySync < ApplicationRecord
  belongs_to :user
  validates :steam_id, format: { with: /\A\d{17}\z/ }
end
