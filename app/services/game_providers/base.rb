# frozen_string_literal: true

module GameProviders
  class Base
    class Unavailable < StandardError; end
    class RateLimited < Unavailable; end
    LOCK = Mutex.new

    def initialize(deadline: nil, fresh: false)
      @deadline = deadline
      @fresh = fresh
    end

    def health
      MediaSources::Registry::CACHE.read(['game-provider-health', name]) || { state: 'unprobed' }
    end

    def enabled?
      MediaSources::Registry.enabled?(name, 'VideoGame')
    end

    def capabilities
      %i[search details artwork external_identifiers].freeze
    end

    private

    def json(url, query = {})
      raise Unavailable unless enabled?

      cache = MediaSources::Registry::CACHE
      uri = URI(url)
      uri.query = URI.encode_www_form(query) if query.any?
      key = ['game-provider-response', name, Digest::SHA256.hexdigest(uri.to_s)]
      cached = cache.read(key) unless @fresh
      return cached if cached
      raise Unavailable if cache.read([key, 'failed']) || health[:state] == 'circuit_open'

      claim_request!
      data = JSON.parse(request_body(uri))
      raise Unavailable unless data.is_a?(Hash)

      cache.write(key, data, expires_in: 6.hours)
      record_success
      data
    rescue MediaSources::Http::Error, JSON::ParserError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError => e
      record_failure(key, e)
      raise(e.is_a?(MediaSources::Http::Error) && e.message == 'HTTP 429' ? RateLimited : Unavailable)
    end

    def record_success
      MediaSources::Registry::CACHE.write(['game-provider-health', name],
                                          { state: 'ready', succeeded_at: Time.current, failures: 0 }, expires_in: 1.day)
    end

    def record_failure(key, error)
      cache = MediaSources::Registry::CACHE
      failures = health.fetch(:failures, 0) + 1
      cache.write([key, 'failed'], true, expires_in: 1.minute)
      state = { state: failures >= 3 ? 'circuit_open' : 'degraded', attempted_at: Time.current,
                failures: failures, reason: error.class.name }
      cache.write(['game-provider-health', name], state, expires_in: 1.minute)
    end

    def request_body(uri)
      attempts = 0
      begin
        attempts += 1
        MediaSources::Http.get(uri, deadline: @deadline, options: { headers: request_headers })
      rescue MediaSources::Http::Error, Timeout::Error, SocketError => e
        transient = !e.is_a?(MediaSources::Http::Error) || e.message.match?(/\AHTTP 5\d\d\z/)
        remaining = @deadline.nil? || @deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC) > 1
        raise unless transient && attempts < 2 && remaining

        claim_request!
        sleep(0.05 + (rand * 0.1))
        retry
      end
    end

    def request_headers
      {}
    end

    def claim_request!
      LOCK.synchronize do
        cache = MediaSources::Registry::CACHE
        key = ['game-provider-budget', name, Time.current.to_i / 60]
        used = cache.read(key).to_i
        variable = "GAME_#{name.upcase}_REQUESTS_PER_MINUTE"
        limit = ENV.fetch(variable, ENV.fetch('GAME_PROVIDER_REQUESTS_PER_MINUTE', '60')).to_i.clamp(1, 300)
        raise RateLimited if used >= limit

        cache.write(key, used + 1, expires_in: 2.minutes)
      end
    end
  end
end
