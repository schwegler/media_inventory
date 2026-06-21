# frozen_string_literal: true

require 'net/http'
require 'json'
require 'time'

class BlueskyClient
  def initialize(user)
    @user = user
  end

  def pds_url
    @pds_url ||= begin
      require 'didkit'
      resolver = DIDKit::Resolver.new
      resolver.resolve_did(@user.bsky_did).pds_endpoint
    rescue StandardError => e
      Rails.logger.error "Failed to resolve PDS for #{@user.bsky_did}: #{e.message}"
      'https://bsky.social'
    end
  end

  def post(text)
    return false unless @user && @user.bsky_access_token.present?

    client = AtProto::Client.new(
      private_key: OmniAuth::Atproto::KeyManager.current_private_key,
      access_token: @user.bsky_access_token
    )

    body = {
      repo: @user.bsky_did,
      collection: 'app.bsky.feed.post',
      record: {
        '$type' => 'app.bsky.feed.post',
        text: text,
        createdAt: Time.now.utc.iso8601
      }
    }

    client.request(:post, "#{pds_url}/xrpc/com.atproto.repo.createRecord", body: body)
    true
  rescue StandardError => e
    Rails.logger.error "Bluesky posting error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if e.respond_to?(:backtrace)
    false
  end

  def profile
    return nil unless @user && @user.bsky_access_token.present?

    client = AtProto::Client.new(
      private_key: OmniAuth::Atproto::KeyManager.current_private_key,
      access_token: @user.bsky_access_token
    )

    client.request(:get, "#{pds_url}/xrpc/app.bsky.actor.getProfile", params: { actor: @user.bsky_did })
  rescue StandardError => e
    Rails.logger.error "Bluesky getProfile error: #{e.message}"
    nil
  end

  def resolve_handle(handle)
    client = AtProto::Client.new(
      private_key: OmniAuth::Atproto::KeyManager.current_private_key,
      access_token: nil
    )
    response = client.request(:get, 'https://bsky.social/xrpc/com.atproto.identity.resolveHandle',
                              params: { handle: handle })
    response['did']
  rescue StandardError => e
    Rails.logger.error "Bluesky resolveHandle error: #{e.message}"
    nil
  end
end
