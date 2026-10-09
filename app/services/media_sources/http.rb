# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

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

    def self.get(url, max_bytes: MAX_JSON_BYTES, redirects: 3, deadline: nil, headers: {}, &consumer)
      uri = validated_uri(url)
      deadline ||= Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raise Error, 'Request deadline exceeded' unless remaining.positive?

      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'TroveMediaInventory/2.0'
      request['Accept-Encoding'] = 'identity'
      headers.each { |key, value| request[key] = value }
      result = nil
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: [remaining, 3].min,
                                          read_timeout: [remaining, 5].min, write_timeout: [remaining, 3].min) do |http|
        http.request(request) do |response|
          if response.is_a?(Net::HTTPRedirection)
            raise Error, 'Too many redirects' unless redirects.positive? && response['location'].present?

            destination = URI.join(uri, response['location'])
            redirect_headers = destination.host == uri.host ? headers : {}
            result = get(destination, max_bytes: max_bytes, redirects: redirects - 1,
                                      deadline: deadline, headers: redirect_headers, &consumer)
          else
            result = read_response(response, max_bytes, deadline, &consumer)
          end
        end
      end
      result
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
