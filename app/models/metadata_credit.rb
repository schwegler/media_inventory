# frozen_string_literal: true

class MetadataCredit < ApplicationRecord
  belongs_to :metadata_entity
  belongs_to :item, polymorphic: true
  validates :role, :source, presence: true
end
