# frozen_string_literal: true

module SessionsHelper
  # Logs in the given user.
  def log_in(user)
    discovery = session[:discovery_intent] unless session[:user_id]
    reset_session
    session[:discovery_intent] = discovery if DiscoveryIntent.read(discovery)
    session[:user_id] = user.id
    session[:session_generation] = user.session_generation
    @current_user = user
  end

  # Returns the current logged-in user (if any).
  def current_user
    return @current_user if defined?(@current_user)

    if session[:user_id]
      @current_user = session_user
      reset_session unless @current_user
      return @current_user
    end

    restored = RememberedDevice.restore(cookies.encrypted[:remembered_device])
    return @current_user = nil unless restored

    device, replacement = restored
    log_in(device.user)
    session[:remembered_device_id] = device.id
    session[:session_generation] = device.session_generation
    write_remembered_cookie(device, replacement) if replacement
    @current_user
  end

  def write_remembered_cookie(device, token)
    cookies.encrypted[:remembered_device] = {
      value: "#{device.id}.#{token}", expires: device.expires_at,
      httponly: true, secure: Rails.env.production?, same_site: :lax, path: '/'
    }
  end

  def forget_device
    # Rails authenticates this encrypted cookie, including the device selector.
    # Revocation must also work with a superseded or expired bearer credential.
    id = cookies.encrypted[:remembered_device].to_s.split('.', 2).first
    RememberedDevice.where(id: id).delete_all if id&.match?(/\A[0-9]+\z/)
    if session[:remembered_device_id]
      RememberedDevice.where(id: session[:remembered_device_id],
                             user_id: session[:user_id]).delete_all
    end
    cookies.delete(:remembered_device, path: '/', secure: Rails.env.production?, same_site: :lax)
  end

  def remember_device(user)
    device, token = RememberedDevice.issue(user)
    write_remembered_cookie(device, token)
    session[:remembered_device_id] = device.id
  end

  def finish_oauth_login(user, provider)
    intent = session.delete(:remember_device_oauth)
    return if current_user

    remember = intent.is_a?(Hash) && intent['provider'] == provider && intent['remember'] == true
    forget_device
    log_in(user)
    remember_device(user) if remember
  end

  def session_user
    user = User.find_by(id: session[:user_id])
    return unless user && session.fetch(:session_generation, 0) == user.session_generation
    return user unless session[:remembered_device_id]

    user if user.remembered_devices.where(id: session[:remembered_device_id])
                .where('expires_at > ?', Time.current).exists?
  end

  # Returns true if the given user is the current user.
  def current_user?(user)
    user == current_user
  end

  # Returns true if the user is logged in, false otherwise.
  def logged_in?
    !current_user.nil?
  end

  # Logs out the current user.
  def log_out
    forget_device
    reset_session
    @current_user = nil
  end
end
