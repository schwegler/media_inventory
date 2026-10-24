# frozen_string_literal: true

require 'net/http'
require 'json'

# Public identity metadata only; never forwards OAuth credentials to AppView.
class BlueskyPublicProfile
  def self.fetch(did)
    uri = URI('https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile')
    uri.query = URI.encode_www_form(actor: did)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 3) do |http|
      http.get(uri.request_uri)
    end
    return {} unless response.is_a?(Net::HTTPSuccess)

    profile = JSON.parse(response.body)
    return {} unless profile.is_a?(Hash) && profile['did'] == did

    profile.slice('handle', 'displayName').select { |_key, value| value.is_a?(String) }
  rescue JSON::ParserError, IOError, SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError
    {}
  end
end
