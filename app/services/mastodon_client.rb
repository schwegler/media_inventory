# frozen_string_literal: true

require 'net/http'
require 'json'

class MastodonClient
  def initialize(user)
    @user = user
  end

  def post(text)
    return false unless @user && @user.mastodon_server.present? && @user.mastodon_access_token.present?

    uri = URI("https://#{@user.mastodon_server}/api/v1/statuses")
    req = Net::HTTP::Post.new(uri, {
                                'Content-Type' => 'application/json',
                                'Authorization' => "Bearer #{@user.mastodon_access_token}"
                              })

    req.body = {
      status: text,
      visibility: 'public'
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    if response.code == '200'
      true
    else
      Rails.logger.error "Mastodon posting error: #{response.body}"
      false
    end
  rescue StandardError => e
    Rails.logger.error "Mastodon posting error: #{e.message}"
    false
  end
end
