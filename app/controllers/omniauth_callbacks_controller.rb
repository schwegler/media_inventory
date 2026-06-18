# frozen_string_literal: true

class OmniauthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[setup atproto mastodon]

  def setup
    request = env['omniauth.strategy'].request
    provider = env['omniauth.strategy'].name

    case provider
    when 'mastodon'
      setup_mastodon(request)
    when 'atproto'
      setup_atproto(request)
    end
  end

  def mastodon
    auth = request.env['omniauth.auth']
    user = find_or_initialize_mastodon_user(auth)

    user.mastodon_server = auth.extra.server
    user.mastodon_access_token = auth.credentials.token
    user.mastodon_refresh_token = auth.credentials.refresh_token

    if user.new_record?
      user.name = auth.info.name || auth.info.nickname
      user.username = auth.info.nickname
      user.email = auth.info.email
      # Generate a random password for new OAuth users
      user.password = SecureRandom.hex(16)
    end
    user.save!

    session[:user_id] = user.id unless current_user
    redirect_to root_path, notice: 'Successfully connected to Mastodon!'
  end

  def atproto
    auth = request.env['omniauth.auth']
    user = current_user || User.find_by(bsky_did: auth.uid) || User.new

    user.bsky_did = auth.uid
    user.bsky_handle = auth.info.nickname || auth.uid
    user.bsky_access_token = auth.credentials.token
    user.bsky_refresh_token = auth.credentials.refresh_token

    if user.new_record?
      user.name = auth.info.name || user.bsky_handle
      user.username = user.bsky_handle.gsub(/[^a-zA-Z0-9_]/, '_')
      user.password = SecureRandom.hex(16)
    end
    user.save!

    session[:user_id] = user.id unless current_user
    redirect_to root_path, notice: 'Successfully connected to Bluesky!'
  end

  def failure
    redirect_to root_path, alert: "Authentication failed: #{params[:message]}"
  end

  private

  def setup_mastodon(request)
    server = request.params['mastodon_server']
    if server.blank?
      render plain: 'Mastodon server required', status: 400
      return
    end

    callback_url = url_for(action: :mastodon, controller: 'omniauth_callbacks', only_path: false)
    callback_url.sub!(%r{/setup$}, '/callback')

    app = MastodonAppRegistration.register(server, callback_url)
    unless app
      render plain: "Failed to register application on #{server}", status: 500
      return
    end

    env['omniauth.strategy'].options.client_id = app.client_id
    env['omniauth.strategy'].options.client_secret = app.client_secret
    env['omniauth.strategy'].options.client_options.site = "https://#{app.server}"
    render plain: 'Setup complete', status: 404
  end

  def setup_atproto(request)
    handle = request.params['bsky_handle']
    env['omniauth.strategy'].options.handle = handle if handle.present?

    client_id = ENV.fetch('BSKY_CLIENT_ID',
                          url_for(controller: 'client_metadata', action: :show, format: :json, only_path: false))
    env['omniauth.strategy'].options.client_id = client_id
    render plain: 'Setup complete', status: 404
  end

  def find_or_initialize_mastodon_user(auth)
    user = current_user || User.find_by(mastodon_uid: auth.uid) || User.new
    user.mastodon_uid = auth.uid
    user
  end
end
