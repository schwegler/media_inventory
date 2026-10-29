# frozen_string_literal: true

module HasMetadataEntities
  extend ActiveSupport::Concern

  included do
    attr_accessor :importing_metadata

    has_many :metadata_credits, as: :item, dependent: :destroy
    has_many :metadata_entities, through: :metadata_credits
    after_save :synchronize_metadata_entities
  end

  private

  def synchronize_metadata_entities
    MetadataEntitySync.call(self)
  end
end
