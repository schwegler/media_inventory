# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'digest'

module MediaSources
  # Both metadata and cover downloads use fixed public provider domains. Redirects
  # pass the same checks; submitted form URLs cannot reach internal services.
  class Http
    HOSTS = %w[api.themoviedb.org image.tmdb.org api.rawg.io media.rawg.io api.steampowered.com store.steampowered.com
               steamgriddb.com
               steamstatic.com steamcdn-a.akamaihd.net itunes.apple.com mzstatic.com
               api.tvmaze.com static.tvmaze.com musicbrainz.org coverartarchive.org
               archive.org comicvine.gamespot.com
               openlibrary.org covers.openlibrary.org en.wikipedia.org wikimedia.org].freeze
    class Error < StandardError; end
    MAX_JSON_BYTES = 2.megabytes

    def self.get(url, max_bytes: MAX_JSON_BYTES, redirects: 3, deadline: nil, options: {}, &consumer)
      uri = validated_uri(url)
      deadline ||= Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raise Error, 'Request deadline exceeded' unless remaining.positive?

      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'TroveMediaInventory/2.0'
      request['Accept-Encoding'] = 'identity'
      options.fetch(:headers, {}).each { |key, value| request[key] = value }
      settings = options.merge(max_bytes: max_bytes, redirects: redirects, deadline: deadline)
      result = nil
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: [remaining, 2].min,
                                          read_timeout: [remaining, 3].min, write_timeout: [remaining, 3].min) do |http|
        http.request(request) { |response| result = response_result(response, uri, settings, &consumer) }
      end
      result
    end

    def self.response_result(response, uri, settings, &consumer)
      if response.is_a?(Net::HTTPRedirection) && !response.is_a?(Net::HTTPNotModified)
        raise Error, 'Too many redirects' unless settings[:redirects].positive? && response['location'].present?

        destination = URI.join(uri, response['location'])
        forwarded_headers = destination.host == uri.host ? settings[:headers] : {}
        return get(destination, max_bytes: settings[:max_bytes],
                                redirects: settings[:redirects] - 1, deadline: settings[:deadline],
                                options: { metadata: settings[:metadata], headers: forwarded_headers }, &consumer)
      end

      settings[:metadata]&.merge!(etag: response['etag'], status: response.code.to_i)
      return if response.is_a?(Net::HTTPNotModified) && settings.dig(:headers, 'If-None-Match') && !consumer

      read_response(response, settings[:max_bytes], settings[:deadline], &consumer)
    end

    # Keep provider payloads on disk, with a bounded body and conditional revalidation.
    # Hash URLs so tokens never become filesystem names. Cover streams bypass this cache.
    def self.cached_get(url, expires_in: 7.days, deadline: nil, revalidate: false)
      validated_uri(url)
      key = ['provider-http-v1', Digest::SHA256.hexdigest(url.to_s)]
      cache = MediaSources::Registry::CACHE
      entry = cache.read(key)
      return entry[:body] if !revalidate && entry && entry[:fresh_until] > Time.current

      metadata = {}
      headers = entry && entry[:etag].present? ? { 'If-None-Match' => entry[:etag] } : {}
      body = get(url, deadline: deadline, options: { headers: headers, metadata: metadata })
      body = entry.fetch(:body) if metadata[:status] == 304
      # Never cache invalid JSON or error responses, which would poison subsequent searches.
      JSON.parse(body)
      cache.write(key, { body: body, etag: metadata[:etag] || entry&.dig(:etag),
                         fresh_until: Time.current + expires_in }, expires_in: expires_in + 30.days)
      body
    end

    def self.validated_uri(url)
      uri = URI(url.to_s)
      allowed = HOSTS.any? { |host| uri.host == host || uri.host&.end_with?(".#{host}") }
      raise Error, 'Unsupported media host' unless uri.is_a?(URI::HTTPS) && allowed && uri.userinfo.nil? && uri.port == 443

      uri
    rescue URI::InvalidURIError
      raise Error, 'Invalid media URL'
    end

    def self.read_response(response, max_bytes, deadline, &consumer)
      raise Error, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      raise Error, 'Response too large' if response['content-length'].to_i > max_bytes

      size = 0
      body = +''.b
      response.read_body do |chunk|
        size += chunk.bytesize
        raise Error, 'Response too large' if size > max_bytes
        raise Error, 'Request deadline exceeded' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        consumer ? consumer.call(chunk, response['content-type']) : body << chunk
      end
      body
    end
  end
end
