# frozen_string_literal: true

class MediaArtworkRendition < ApplicationRecord
  SIZES = [[180, 270], [360, 540]].freeze
  belongs_to :source_blob, class_name: 'ActiveStorage::Blob'
  belongs_to :blob, class_name: 'ActiveStorage::Blob', optional: true
  validates :requested_width, :requested_height, numericality: { only_integer: true, greater_than: 0 }

  def self.request(source)
    limit = ENV.fetch('MEDIA_ARTWORK_QUEUE_LIMIT', '100').to_i.clamp(1, 1000)
    return if where(state: %w[pending processing]).count >= limit

    SIZES.each do |width, height|
      row = find_or_create_by!(source_blob: source, requested_width: width, requested_height: height)
      retry_claimed = !row.previously_new_record? && where(id: row.id, state: 'failed')
                      .update_all(state: 'pending', failure_reason: nil, updated_at: Time.current).positive?
      next unless row.previously_new_record? || retry_claimed

      GenerateMediaArtworkRenditionJob.perform_later(row)
    end
  end
end
