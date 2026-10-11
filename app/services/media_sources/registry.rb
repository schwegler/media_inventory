# frozen_string_literal: true

module MediaSources
  class Registry
    # FileStore works even when development's page cache is disabled.
    CACHE = ActiveSupport::Cache::FileStore.new(
      ENV.fetch('RAILS_CACHE_PATH', Rails.root.join('tmp/cache', Rails.env).to_s)
    )
    # Search workers use a shared read-only snapshot without occupying DB connections.
    def self.with_snapshot(configurations)
      previous = Thread.current[:media_source_configurations]
      Thread.current[:media_source_configurations] = configurations
      yield
    ensure
      Thread.current[:media_source_configurations] = previous
    end

    def self.configuration(source, type)
      snapshot = Thread.current[:media_source_configurations]
      return snapshot.find { |config| config.source_name == source && config.media_type == type } if snapshot

      ApiConfiguration.find_by(source_name: source, media_type: type)
    end

    def self.enabled?(source, type)
      config = configuration(source, type)
      config.nil? || config.is_active?
    end

    def self.token(source, type)
      config = configuration(source, type)
      config ||= configuration(source, nil)
      config&.is_active? ? config.access_token.presence : nil
    end
  end
end
