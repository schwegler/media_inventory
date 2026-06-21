# frozen_string_literal: true

require_relative '../../lib/omniauth/strategies/mastodon'
require 'omniauth-atproto/key_manager'

module OmniAuth
  module Atproto
    module KeyManagerPatch
      def load_or_generate_keys
        if ENV['BSKY_PRIVATE_KEY'].present? && ENV['BSKY_JWK'].present?
          begin
            private_key_pem = ENV['BSKY_PRIVATE_KEY'].gsub('\\n', "\n")
            private_key = OpenSSL::PKey::EC.new(private_key_pem)
            jwk = JSON.parse(ENV.fetch('BSKY_JWK', nil), symbolize_names: true)
            return [private_key, jwk]
          rescue StandardError => e
            Rails.logger.error "Failed to load keys from ENV: #{e.message}"
          end
        end
        super
      end
    end
  end
end

OmniAuth::Atproto::KeyManager.singleton_class.prepend(OmniAuth::Atproto::KeyManagerPatch)

Rails.application.config.middleware.use OmniAuth::Builder do
  # Bluesky / AT Proto OAuth
  # The atproto strategy requires a client_id. According to AT Protocol OAuth specs,
  # the client_id is a URL pointing to the client-metadata.json.
  provider :atproto, ENV.fetch('BSKY_CLIENT_ID', nil),
           setup: true,
           scope: 'atproto transition:generic',
           private_key: OmniAuth::Atproto::KeyManager.current_private_key,
           client_jwk: OmniAuth::Atproto::KeyManager.current_jwk

  # Mastodon OAuth (Dynamic)
  provider :mastodon, setup: true
end

OmniAuth.config.allowed_request_methods = %i[post get]
OmniAuth.config.silence_get_warning = true
