# frozen_string_literal: true

module GameProviders
  class EntityMetadata
    def self.call(data, provider)
      credits = %w[developers publishers genres platforms].flat_map do |field|
        role, kind = { 'developers' => %w[Developer organization], 'publishers' => %w[Publisher organization],
                       'genres' => %w[Genre genre], 'platforms' => %w[Platform platform] }.fetch(field)
        rows = data[field]
        rows = rows.select { |_name, supported| supported }.keys if rows.is_a?(Hash)
        Array(rows).filter_map do |entry|
          row = entry.is_a?(Hash) ? (entry['platform'] || entry) : { 'name' => entry }
          row = row.merge('name' => row['description']) if row['name'].blank? && row['description'].present?
          namespace = kind == 'organization' ? "#{provider}:#{field}" : provider
          ProviderEntityMetadata.credit(row, role, namespace, kind: kind)
        end
      end
      credits + Array(data['series']).filter_map do |row|
        ProviderEntityMetadata.credit(row, 'Series', provider, kind: 'series')
      end
    end
  end
end
