# frozen_string_literal: true

ActiveSupport.on_load(:active_storage_blob) do
  has_many :artwork_renditions, class_name: 'MediaArtworkRendition', foreign_key: :source_blob_id,
                                dependent: :delete_all, inverse_of: :source_blob
end
