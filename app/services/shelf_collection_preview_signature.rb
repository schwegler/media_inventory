# frozen_string_literal: true

# Pure fingerprint shared by publication and discovery, with no database lookup.
class ShelfCollectionPreviewSignature
  def self.call(collection, username: collection.user.username)
    identity = [username, collection.title, collection.description, collection.picks]
    if collection.has_attribute?(:allowed_media_types) && collection.has_attribute?(:preview_length)
      identity += [collection.allowed_media_types, collection.preview_length, collection.presentation]
      version = 'collection-v3-full-shelf'
    else
      # Supports the pre-display-settings schema during integration/rolling upgrades.
      version = 'collection-v2-campaign'
    end
    Digest::SHA256.hexdigest([version, *identity].to_json)
  end
end
