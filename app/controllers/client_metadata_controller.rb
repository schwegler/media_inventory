# frozen_string_literal: true

class ClientMetadataController < ApplicationController
  def show
    render json: {
      client_id: client_metadata_url(format: :json),
      client_name: 'Media Inventory',
      redirect_uris: [url_for(controller: 'omniauth_callbacks', action: :atproto, only_path: false)],
      scopes: ['atproto'],
      grant_types: %w[authorization_code refresh_token],
      response_types: ['code'],
      token_endpoint_auth_method: 'none',
      application_type: 'web',
      dpop_bound_access_tokens: true
    }
  end
end
