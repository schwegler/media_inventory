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

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    if response.code == '200'
      true
    else
      Rails.logger.error "Bluesky posting error: #{response.body}"
      false
    end
  rescue StandardError => e
    Rails.logger.error "Bluesky posting error: #{e.message}"
    false
  end

  def get_profile
    return nil unless @user && @user.bsky_access_token.present?

    uri = URI("#{BASE_URL}/app.bsky.actor.getProfile")
    uri.query = URI.encode_www_form(actor: @user.bsky_did)

    req = Net::HTTP::Get.new(uri, {
      'Authorization' => "Bearer #{@user.bsky_access_token}"
    })

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    if response.code == '200'
      JSON.parse(response.body)
    else
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Bluesky getProfile error: #{e.message}"
    nil
  end
end
