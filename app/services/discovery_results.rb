# frozen_string_literal: true

# Provider identity wins over title/year heuristics; never invent a catalog row.
class DiscoveryResults
  def self.call(results, type, user: nil)
    return results unless MetadataImport::TYPES.include?(type)

    klass = type.camelize.constantize
    ids = results.filter_map { |item| item[:api_id].presence }
    urls = results.filter_map { |item| item[:external_url].presence }
    records = klass.where(api_id: ids).or(klass.where(external_url: urls)).order(:id).to_a
    membership = user ? user.library_items.where(item_type: klass.name, item_id: records.map(&:id)).pluck(:item_id) : []
    results.map do |result|
      record = existing_record(records, result)
      record ? result.merge(is_local: true, catalog_id: record.id, in_library: membership.include?(record.id)) : result
    end
  end

  def self.existing_record(records, result)
    if result[:api_id].present?
      records.find { |item| item.api_id == result[:api_id] }
    elsif result[:external_url].present?
      records.find { |item| item.external_url == result[:external_url] }
    end
  end
end
