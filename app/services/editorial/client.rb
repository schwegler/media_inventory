# frozen_string_literal: true

module Editorial
  # Reuse streaming bounds and deadlines without adding WordPress to the shared
  # provider allowlist. No arbitrary endpoints, credentials or redirects.
  class Client < MediaSources::Http
    class Unavailable < StandardError; end
    class Removed < StandardError; end
    class PageDrift < Unavailable; end
    ENDPOINT = 'https://tacobout.online/wp-json/wp/v2/posts'

    def self.validated_uri(value)
      uri = Urls.secure_uri(value.to_s)
      unless uri && uri.host == 'tacobout.online' && uri.path.match?(%r{\A/wp-json/wp/v2/posts(?:/[1-9]\d*)?\z})
        raise Error, 'Unsupported editorial endpoint'
      end

      uri
    end

    attr_reader :total_pages

    def self.response_result(response, uri, settings, &)
      settings[:metadata]&.merge!(total_pages: response['x-wp-totalpages'], status: response.code.to_i)
      super
    end

    def fetch(params: {}, id: nil)
      url = id ? "#{ENDPOINT}/#{Integer(id)}" : ENDPOINT
      url += "?#{URI.encode_www_form(params.merge(_embed: 'wp:featuredmedia'))}"
      attempts = 0
      begin
        attempts += 1
        metadata = {}
        body = self.class.get(url, redirects: 0, options: { metadata: metadata })
        if id.nil? && !metadata[:total_pages].to_s.match?(/\A\d+\z/)
          raise Unavailable, 'Missing WordPress pagination metadata'
        end

        @total_pages = metadata[:total_pages].to_i
        JSON.parse(body)
      rescue MediaSources::Http::Error, Timeout::Error, SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError => e
        status = metadata[:status]
        raise Removed, "HTTP #{status}" if removed_post?(id, status)
        raise PageDrift, 'Collection page rejected; replay frozen window' if rejected_page?(id, params, status)

        if attempts < 3 && (status.nil? || status == 429 || status >= 500)
          sleep(0.25 * (2**(attempts - 1)))
          retry
        end
        raise Unavailable, "WordPress request failed (#{status || e.class})"
      rescue JSON::ParserError
        raise Unavailable, 'Invalid WordPress JSON'
      end
    end

    private

    def removed_post?(id, status)
      id.present? && [404, 410].include?(status)
    end

    def rejected_page?(id, params, status)
      id.nil? && status == 400 && params[:page].to_i > 1
    end
  end
end
