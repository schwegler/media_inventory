# frozen_string_literal: true

class MetadataIdentity < ApplicationRecord
  belongs_to :metadata_entity
  validates :provider, :external_id, presence: true
end
