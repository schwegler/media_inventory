# frozen_string_literal: true

class ClientMetadataController < ApplicationController
  def show
    render json: {
      client_id: client_metadata_url,
      client_name: 'Media Inventory',
      redirect_uris: [url_for(controller: 'omniauth_callbacks', action: :atproto, provider: 'atproto', only_path: false)],
      scope: 'atproto transition:generic',
      grant_types: %w[authorization_code refresh_token],
      response_types: ['code'],
      token_endpoint_auth_method: 'private_key_jwt',
      token_endpoint_auth_signing_alg: 'ES256',
      application_type: 'web',
      dpop_bound_access_tokens: true,
      jwks: { keys: [OmniAuth::Atproto::KeyManager.current_jwk] }
    }
  end
end
