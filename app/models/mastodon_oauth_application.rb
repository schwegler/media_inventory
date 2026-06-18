# frozen_string_literal: true

class MastodonOauthApplication < ApplicationRecord
  validates :server, presence: true, uniqueness: true
  validates :client_id, presence: true
  validates :client_secret, presence: true
end
