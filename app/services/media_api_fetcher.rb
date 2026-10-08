# frozen_string_literal: true

# Search and enrichment share providers. Only matching works may fill empty fields.
class MediaApiFetcher
  def self.call(item)
    MediaSearchService.call(item.title, item.class.name.underscore).each do |result|
      merge_missing_fields(item, result) if same_release?(item, result)
    end
    item.save! if item.changed?
    item
  end

  def self.same_release?(item, result)
    return false unless result[:title].to_s.casecmp?(item.title.to_s)
    return true unless item.respond_to?(:release_year) && item.release_year.present? && result[:release_year].present?

    item.release_year.to_s == result[:release_year].to_s
  end

  def self.merge_missing_fields(item, result)
    result.except(:title, :source, :is_local).each do |field, value|
      next if value.blank? || !item.respond_to?("#{field}=") || item.public_send(field).present?
      next if field == :thumbnail_url && item.cover_image.attached?

      item.public_send("#{field}=", value)
    end
  end
end
