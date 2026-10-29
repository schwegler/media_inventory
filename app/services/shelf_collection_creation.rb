# frozen_string_literal: true

# A form nonce gives retries one stable identity; the existing unique slug index
# also prevents simultaneous submissions from creating duplicate shelves.
class ShelfCollectionCreation
  def self.call(user, attributes, token:, presentation:)
    slug = "shelf-#{Digest::SHA256.hexdigest(token).first(24)}"
    collection = user.shelf_collections.find_by(slug: slug)
    return collection if collection

    collection = user.shelf_collections.new(attributes.merge(slug: slug, presentation: presentation))
    collection.save
    collection
  rescue ActiveRecord::RecordNotUnique
    user.shelf_collections.find_by!(slug: slug)
  end
end
