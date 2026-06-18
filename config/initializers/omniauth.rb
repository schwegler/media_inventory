# frozen_string_literal: true

require_relative '../../lib/omniauth/strategies/mastodon'

Rails.application.config.middleware.use OmniAuth::Builder do
  # Bluesky / AT Proto OAuth
  # The atproto strategy requires a client_id. According to AT Protocol OAuth specs,
  # the client_id is a URL pointing to the client-metadata.json.
  provider :atproto, ENV.fetch('BSKY_CLIENT_ID', nil), setup: true

  # Mastodon OAuth (Dynamic)
  provider :mastodon, setup: true
end

OmniAuth.config.allowed_request_methods = %i[post get]
OmniAuth.config.silence_get_warning = true
