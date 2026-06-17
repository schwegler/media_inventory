# frozen_string_literal: true

require 'net/http'
require 'json'
require 'time'

class BlueskyClient
  BASE_URL = 'https://bsky.social/xrpc'

  def initialize(handle, app_password)
    @handle = handle
    @app_password = app_password
  end

  # Authenticates and returns session data (accessJwt and did) or nil if failed
  def authenticate
    return nil if @handle.blank? || @app_password.blank?

    uri = URI("#{BASE_URL}/com.atproto.server.createSession")
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = { identifier: @handle, password: @app_password }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    return nil unless response.code == '200'

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error "Bluesky authentication error: #{e.message}"
    nil
  end

  # Posts a message (skeet)
  def post(text)
    session = authenticate
    return false unless session

    uri = URI("#{BASE_URL}/com.atproto.repo.createRecord")
    req = Net::HTTP::Post.new(uri, {
                                'Content-Type' => 'application/json',
                                'Authorization' => "Bearer #{session['accessJwt']}"
                              })

    req.body = {
      repo: session['did'],
      collection: 'app.bsky.feed.post',
      record: {
        '$type' => 'app.bsky.feed.post',
        text: text,
        createdAt: Time.now.utc.iso8601
      }
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    response.code == '200'
  rescue StandardError => e
    Rails.logger.error "Bluesky posting error: #{e.message}"
    false
  end

  # Fetches profile information for a given actor handle or DID
  def get_profile(actor)
    session = authenticate
    return nil unless session

    uri = URI("#{BASE_URL}/app.bsky.actor.getProfile")
    uri.query = URI.encode_www_form(actor: actor)

    req = Net::HTTP::Get.new(uri, {
                               'Authorization' => "Bearer #{session['accessJwt']}"
                             })

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    return nil unless response.code == '200'

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error "Bluesky getProfile error: #{e.message}"
    nil
  end
end
