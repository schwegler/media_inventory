# frozen_string_literal: true

class OmniAuthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[setup atproto mastodon]

  def setup
    return render plain: 'Setup complete', status: 404 if Rails.env.test?

    req = request.env['omniauth.strategy'].request
    provider = request.env['omniauth.strategy'].name

    case provider
    when 'mastodon'
      setup_mastodon(req)
    when 'atproto'
      setup_atproto(req)
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
      user.username = User.generate_unique_username(auth.info.nickname)
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
      user.username = User.generate_unique_username(user.bsky_handle)
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

  # rubocop:disable Metrics/AbcSize
  def setup_mastodon(req)
    server = req.params['mastodon_server'] || request.params['mastodon_server'] || session[:mastodon_server]
    if server.blank?
      render plain: "Mastodon server required.
              req.params: #{req.params.inspect},
              request.params: #{request.params.inspect}",
             status: 400
      return
    end

    session[:mastodon_server] = server

    callback_url = url_for(action: :mastodon, controller: 'omniauth_callbacks', only_path: false)
    callback_url.sub!(%r{/setup$}, '/callback')

    app = MastodonAppRegistration.register(server, callback_url)
    unless app
      render plain: "Failed to register application on #{server}", status: 500
      return
    end

    request.env['omniauth.strategy'].options.client_id = app.client_id
    request.env['omniauth.strategy'].options.client_secret = app.client_secret
    request.env['omniauth.strategy'].options.client_options.site = "https://#{app.server}"
    request.env['omniauth.strategy'].options.scope = 'read write'
    render plain: 'Setup complete', status: 404
  end
  # rubocop:enable Metrics/AbcSize

  def setup_atproto(req)
    handle = req.params['bsky_handle'] || req.params['handle']

    if handle.present?
      request.env['omniauth.strategy'].options.handle = handle
      request.env['rack.request.form_hash'] ||= {}
      request.env['rack.request.form_hash']['handle'] = handle
    end

    # Call the gem's default setup block to resolve DID and PDS authorization server
    # This must be called during both request and callback phases so it can restore session info
    begin
      OmniAuth::Strategies::Atproto.setup.call(request.env)
    rescue StandardError => e
      return render plain: "Bluesky setup failed: #{e.message}", status: 400
    end

    client_id = ENV.fetch('BSKY_CLIENT_ID', client_metadata_url(only_path: false))
    request.env['omniauth.strategy'].options.client_id = client_id
    request.env['omniauth.strategy'].options.scope = 'atproto transition:generic'
    render plain: 'Setup complete', status: 404
  end

  def find_or_initialize_mastodon_user(auth)
    user = current_user || User.find_by(mastodon_uid: auth.uid) || User.new
    user.mastodon_uid = auth.uid
    user
  end
end
