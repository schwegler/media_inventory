# frozen_string_literal: true

require 'net/http'
require 'json'
require 'time'

class BlueskyClient
  BASE_URL = 'https://bsky.social/xrpc'

  def initialize(user)
    @user = user
  end

  def post(text)
    return false unless @user && @user.bsky_access_token.present?

    uri = URI("#{BASE_URL}/com.atproto.repo.createRecord")
    req = build_post_request(uri, text)

    response = execute_request(req, uri)
    return true if response.code == '200'

    Rails.logger.error "Bluesky posting error: #{response.body}"
    false
  rescue StandardError => e
    Rails.logger.error "Bluesky posting error: #{e.message}"
    false
  end

  def profile
    return nil unless @user && @user.bsky_access_token.present?

    uri = URI("#{BASE_URL}/app.bsky.actor.getProfile")
    uri.query = URI.encode_www_form(actor: @user.bsky_did)

    req = Net::HTTP::Get.new(uri, {
                               'Authorization' => "Bearer #{@user.bsky_access_token}"
                             })

    response = execute_request(req, uri)
    JSON.parse(response.body) if response.code == '200'
  rescue StandardError => e
    Rails.logger.error "Bluesky getProfile error: #{e.message}"
    nil
  end

  def resolve_handle(handle)
    uri = URI("#{BASE_URL}/com.atproto.identity.resolveHandle")
    uri.query = URI.encode_www_form(handle: handle)

    req = Net::HTTP::Get.new(uri)
    response = execute_request(req, uri)

    JSON.parse(response.body)['did'] if response.code == '200'
  rescue StandardError => e
    Rails.logger.error "Bluesky resolveHandle error: #{e.message}"
    nil
  end

  private

  def build_post_request(uri, text)
    req = Net::HTTP::Post.new(uri, {
                                'Content-Type' => 'application/json',
                                'Authorization' => "Bearer #{@user.bsky_access_token}"
                              })

    req.body = {
      repo: @user.bsky_did,
      collection: 'app.bsky.feed.post',
      record: {
        '$type' => 'app.bsky.feed.post',
        text: text,
        createdAt: Time.now.utc.iso8601
      }
    }.to_json
    req
  end

  def execute_request(req, uri)
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end
  end
end
