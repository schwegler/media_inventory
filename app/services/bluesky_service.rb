# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class BlueskyService
  def initialize(handle, app_password)
    @handle = handle
    @app_password = app_password
  end

  def post(text)
    session = create_session
    return false unless session

    create_record(session['did'], session['accessJwt'], text)
  end

  private

  def create_session
    uri = URI('https://bsky.social/xrpc/com.atproto.server.createSession')
    req = Net::HTTP::Post.new(uri)
    req.content_type = 'application/json'
    req.body = { identifier: @handle, password: @app_password }.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    return JSON.parse(res.body) if res.is_a?(Net::HTTPSuccess)

    Rails.logger.error "Bluesky Auth Failed: #{res.body}"
    nil
  end

  # rubocop:disable Naming/PredicateMethod
  def create_record(did, token, text)
    uri = URI('https://bsky.social/xrpc/com.atproto.repo.createRecord')
    req = Net::HTTP::Post.new(uri)
    req.content_type = 'application/json'
    req['Authorization'] = "Bearer #{token}"

    req.body = {
      repo: did,
      collection: 'app.bsky.feed.post',
      record: {
        text: text,
        createdAt: Time.now.utc.iso8601,
        '$type': 'app.bsky.feed.post'
      }
    }.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    res.is_a?(Net::HTTPSuccess)
  end
end

# rubocop:enable Naming/PredicateMethod
