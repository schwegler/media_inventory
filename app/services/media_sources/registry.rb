# frozen_string_literal: true

module MediaSources
  class Registry
    # FileStore works even when development's page cache is disabled.
    CACHE = ActiveSupport::Cache::FileStore.new(
      ENV.fetch('RAILS_CACHE_PATH', Rails.root.join('tmp/cache').to_s)
    )
    def self.enabled?(source, type)
      config = ApiConfiguration.find_by(source_name: source, media_type: type)
      config.nil? || config.is_active?
    end

    def self.token(source, type)
      ApiConfiguration.find_by(source_name: source, media_type: type, is_active: true)&.access_token.presence
    end
  end
end
