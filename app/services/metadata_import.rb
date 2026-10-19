# frozen_string_literal: true

# Only server-signed search/detail data may cross the confirmation form.
class MetadataImport
  class Invalid < StandardError; end
  TYPES = %w[movie tv_show album book comic video_game].freeze
  FIELDS = %w[title api_id external_url thumbnail_url director writer actors genre network artist author publisher
              developer platform release_year issue_number game_type synopsis metadata_details metadata_credits_data].freeze

  def self.sign(type, attributes)
    payload = { 'type' => type, 'attributes' => attributes.stringify_keys }
    key = ['metadata-import-token-v1', Digest::SHA256.hexdigest(payload.to_json)]
    MediaSources::Registry::CACHE.fetch(key, expires_in: 20.minutes) do
      Rails.application.message_verifier('metadata-import').generate(payload, expires_in: 30.minutes)
    end
  end

  def self.game_selection(game)
    MediaSources::Registry::CACHE.fetch(['game-catalog-selection-v1', game.id, game.updated_at], expires_in: 20.minutes) do
      game.signed_id(purpose: 'game-catalog-selection', expires_in: 30.minutes)
    end
  end

  def self.read(token, type)
    raise Invalid, 'Import selection is invalid. Search and select the title again.' unless token.is_a?(String)

    value = Rails.application.message_verifier('metadata-import').verified(token)
    raise Invalid, 'Import selection expired or is invalid. Search and select the title again.' unless
      TYPES.include?(type) && value.is_a?(Hash) && value['type'] == type

    value.fetch('attributes').with_indifferent_access
  end

  def self.attributes(data, klass)
    result = data.slice(*FIELDS).select { |field, _| klass.column_names.include?(field.to_s) }
    if klass == Comic && data[:release_year].present? && result[:title].present?
      suffix = " (#{data[:release_year]})"
      result[:title] += suffix unless result[:title].end_with?(suffix)
    end
    result
  end

  def self.preview(data, type)
    klass = type.camelize.constantize
    if data[:is_local]
      item = klass.find(data[:catalog_id])
      return data.merge(item.attributes.slice(*FIELDS).except('thumbnail_url')).merge(
        import_state: 'catalog', source: 'Trove catalog'
      )
    end

    item = klass.new(attributes(data, klass))
    adapter = MetadataProvider.new(item, include_children: false,
                                         deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + 8)
    fields, = adapter.call
    fields = attributes(fields.with_indifferent_access, klass).compact_blank
    fields.delete(:thumbnail_url) if data[:cover_source_url].present?
    data.merge(fields).merge(import_state: adapter.partial ? 'partial' : 'ready', source: adapter.provider)
  rescue MetadataProvider::Unsupported
    data.merge(import_state: 'summary')
  rescue MetadataProvider::Unavailable, MetadataProvider::RateLimited, Timeout::Error, SocketError,
         JSON::ParserError, KeyError
    data.merge(import_state: 'unavailable')
  end
end
