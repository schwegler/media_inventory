# frozen_string_literal: true

module MediaSources
  class Registry
    # FileStore works even when development's page cache is disabled.
    CACHE = ActiveSupport::Cache::FileStore.new(
      ENV.fetch('RAILS_CACHE_PATH', Rails.root.join('tmp/cache', Rails.env).to_s)
    )
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
