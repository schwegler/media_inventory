class OmniauthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[setup atproto mastodon]

  def setup
    request = env['omniauth.strategy'].request
    provider = env['omniauth.strategy'].name

    if provider == 'mastodon'
      server = request.params['mastodon_server']
      if server.blank?
        # Handle error or render form
        render plain: "Mastodon server required", status: 400
        return
      end

      # Construct callback url dynamically
      callback_url = url_for(action: :mastodon, controller: 'omniauth_callbacks', only_path: false)
      callback_url.sub!(%r{/setup$}, '/callback') # Adjust if necessary since omniauth handles callback

      app = MastodonAppRegistration.register(server, callback_url)
      unless app
        render plain: "Failed to register application on #{server}", status: 500
        return
      end

      env['omniauth.strategy'].options.client_id = app.client_id
      env['omniauth.strategy'].options.client_secret = app.client_secret
      env['omniauth.strategy'].options.client_options.site = "https://#{app.server}"

    elsif provider == 'atproto'
      # AT Proto setup might involve resolving the user's handle to their PDS
      # omniauth-atproto handles most of it, but we might need to set dynamic options based on params.
      handle = request.params['bsky_handle']
      if handle.present?
        env['omniauth.strategy'].options.handle = handle
      end
      # We assume BSKY_CLIENT_ID is set in ENV for localhost or production
      client_id = ENV['BSKY_CLIENT_ID'] || url_for(controller: 'client_metadata', action: :show, format: :json, only_path: false)
      env['omniauth.strategy'].options.client_id = client_id
    end

    render plain: "Setup complete", status: 404 # OmniAuth catches 404 from setup and continues to request phase
  end

  def mastodon
    auth = request.env['omniauth.auth']
    user = current_user || User.find_by(mastodon_uid: auth.uid) || User.new

    user.mastodon_uid = auth.uid
    user.mastodon_server = auth.extra.server
    user.mastodon_access_token = auth.credentials.token
    user.mastodon_refresh_token = auth.credentials.refresh_token

    if user.new_record?
      user.name = auth.info.name || auth.info.nickname
      user.username = auth.info.nickname
      user.email = auth.info.email
      # Generate a random password for new OAuth users
      user.password = SecureRandom.hex(16)
      user.save!
    else
      user.save!
    end

    session[:user_id] = user.id unless current_user
    redirect_to root_path, notice: "Successfully connected to Mastodon!"
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
      user.save!
    else
      user.save!
    end

    session[:user_id] = user.id unless current_user
    redirect_to root_path, notice: "Successfully connected to Bluesky!"
  end

  def failure
    redirect_to root_path, alert: "Authentication failed: #{params[:message]}"
  end
end
