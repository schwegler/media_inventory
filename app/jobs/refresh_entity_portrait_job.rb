# frozen_string_literal: true

class RefreshEntityPortraitJob < ApplicationJob
  queue_as :media_imports

  def self.request(entity)
    return unless entity.kind == 'person' && entity.thumbnail_url.blank? && !entity.cover_image.attached?

    claimed = MetadataEntity.where(id: entity.id).where('portrait_checked_at IS NULL OR portrait_checked_at < ?',
                                                        30.days.ago)
                            .update_all(portrait_checked_at: Time.current)
    perform_later(entity.id) if claimed.positive?
  end

  def perform(entity_id)
    entity = MetadataEntity.find_by(id: entity_id)
    EntityPortraitLookup.call(entity) if entity
  end
end
