# frozen_string_literal: true

require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class Mastodon < OmniAuth::Strategies::OAuth2
      option :name, 'mastodon'
      option :scope, 'read write'

      option :client_options, {
        authorize_url: '/oauth/authorize',
        token_url: '/oauth/token'
      }

      uid { raw_info['id'] }

      info do
        {
          nickname: raw_info['username'],
          name: raw_info['display_name'],
          urls: { profile: raw_info['url'] },
          avatar: raw_info['avatar']
        }
      end

      extra do
        {
          raw_info: raw_info,
          server: options.client_options.site.to_s.sub(%r{^https?://}, '').split('/').first
        }
      end

      def raw_info
        @raw_info ||= access_token.get('/api/v1/accounts/verify_credentials').parsed
      end
    end
  end
end
