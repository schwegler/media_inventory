# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class BlueskyService
  def self.post_activity(user, activity_type, trackable)
    return unless user.bsky_handle.present? && user.bsky_app_password.present?

    # Check user preferences
    if user.bsky_post_reviews_only?
      return unless activity_type == 'reviewed'
    end

    message = format_message(user.bsky_custom_message, trackable.title, activity_type, trackable)
    return if message.blank?

    new(user.bsky_handle, user.bsky_app_password).post(message)
  rescue StandardError => e
    Rails.logger.error "BlueskyService Error: \#{e.message}"
  end

  def self.format_message(custom_template, title, activity_type, trackable)
    if custom_template.present?
      custom_template.gsub('[title]', title)
    else
      case activity_type
      when 'added'
        "Just added \#{title} to my collection!"
      when 'watchlist'
        "Just added \#{title} to my watchlist."
      when 'consumed'
        "Just finished watching/reading \#{title}."
      when 'reviewed'
        rating_str = trackable.rating.present? ? " - \#{trackable.rating}★" : ""
        "Just reviewed \#{title}\#{rating_str}: \#{trackable.review}"
      else
        "Activity updated for \#{title}."
      end
    end
  end

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

    Rails.logger.error "Bluesky Auth Failed: \#{res.body}"
    nil
  end

  def create_record(did, token, text)
    uri = URI('https://bsky.social/xrpc/com.atproto.repo.createRecord')
    req = Net::HTTP::Post.new(uri)
    req.content_type = 'application/json'
    req['Authorization'] = "Bearer \#{token}"

    req.body = {
      repo: did,
      collection: 'app.bsky.feed.post',
      record: {
        text: text,
        createdAt: Time.now.utc.iso8601,
        "$type": 'app.bsky.feed.post'
      }
    }.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    res.is_a?(Net::HTTPSuccess)
  end
end
