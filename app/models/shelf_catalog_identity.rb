# frozen_string_literal: true

# A database mutex for one verified external identity, not a catalog uniqueness constraint.
class ShelfCatalogIdentity < ApplicationRecord
  validates :media_type, inclusion: { in: FavoriteShelf::CATEGORIES.keys - ['overall'] }
  validates :identity_key, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :provider_id, presence: true
end
