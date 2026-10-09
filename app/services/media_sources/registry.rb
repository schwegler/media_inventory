# frozen_string_literal: true

module MediaSources
  class Registry
    CACHE = ActiveSupport::Cache::MemoryStore.new(size: 16.megabytes)
    def self.enabled?(source, type)
      config = ApiConfiguration.find_by(source_name: source, media_type: type)
      config.nil? || config.is_active?
    end

    def self.token(source, type)
      config = ApiConfiguration.find_by(source_name: source, media_type: type)
      config ||= ApiConfiguration.find_by(source_name: source, media_type: nil)
      config&.is_active? ? config.access_token.presence : nil
    end
  end
end
