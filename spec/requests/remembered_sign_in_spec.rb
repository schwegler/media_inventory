# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Remembered sign-in', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:user) { User.create!(name: 'Synthetic Member', email: 'remember@example.test', password: 'password123') }

  def sign_in(remember = '0')
    post login_path, params: { session: { email: user.email, password: 'password123', remember_device: remember } }
  end

  def restart_browser
    cookies.delete('_sample_app_session')
  end

  def expect_signed_in
    get edit_user_path(user)
    expect(response).to have_http_status(:ok)
  end

  def expect_signed_out
    get edit_user_path(user)
    expect(response).to redirect_to(login_url)
  end

  it 'restores after loss of the ordinary browser session and rotates both credentials' do
    sign_in('1')
    remembered = cookies[:remembered_device]
    ordinary = cookies['_sample_app_session']
    restart_browser
    expect_signed_in
    expect(cookies[:remembered_device]).not_to eq(remembered)
    expect(cookies['_sample_app_session']).not_to eq(ordinary)
    expect(user.remembered_devices.count).to eq(1)
  end

  it 'restores two windows without the losing response overwriting the winning credential' do
    sign_in('1')
    first_window = ActionDispatch::Integration::Session.new(Rails.application)
    second_window = ActionDispatch::Integration::Session.new(Rails.application)
    [first_window, second_window].each { |client| client.cookies[:remembered_device] = cookies[:remembered_device] }
    first_window.get(edit_user_path(user))
    second_window.get(edit_user_path(user))
    expect(first_window.response).to have_http_status(:ok)
    expect(second_window.response).to have_http_status(:ok)
    expect(Array(second_window.response.headers['set-cookie']).join).not_to include('remembered_device=')
    travel 61.seconds
    [first_window, second_window].each do |client|
      client.get(edit_user_path(user))
      expect(client.response).to have_http_status(:ok)
    end
  end

  it 'keeps unchecked sign-in ephemeral and revokes the previous device' do
    sign_in('1')
    old = cookies[:remembered_device]
    sign_in
    expect(user.remembered_devices).to be_empty
    expect(cookies[:remembered_device]).to be_blank
    restart_browser
    cookies[:remembered_device] = old
    expect_signed_out
  end

  it 'does not persist unchecked or failed sign-in' do
    sign_in
    expect(user.remembered_devices).to be_empty
    expect(cookies[:remembered_device]).to be_blank
    restart_browser
    expect_signed_out
    post login_path, params: { session: { email: user.email, password: 'wrong', remember_device: '1' } }
    expect(user.remembered_devices).to be_empty
  end

  it 'revokes this device and its restored sessions at logout, leaving another device intact' do
    sign_in('1')
    old = cookies[:remembered_device]
    RememberedDevice.issue(user)
    restart_browser
    expect_signed_in
    restored_session = cookies['_sample_app_session']
    delete logout_path
    expect(user.remembered_devices.count).to eq(1)
    expect(cookies[:remembered_device]).to be_blank
    cookies['_sample_app_session'] = restored_session
    expect_signed_out
    restart_browser
    cookies[:remembered_device] = old
    expect_signed_out
  end

  it 'rejects expired credentials and restored sessions at the absolute deadline' do
    sign_in('1')
    restart_browser
    expect_signed_in
    travel_to user.remembered_devices.first.expires_at + 1.second
    expect_signed_out
    restart_browser
    expect_signed_out
  end

  it 'invalidates ordinary and remembered sessions after password changes' do
    sign_in('1')
    old = cookies[:remembered_device]
    user.update!(password: 'changed123')
    expect_signed_out
    restart_browser
    cookies[:remembered_device] = old
    expect_signed_out
  end

  it 'invalidates ordinary sessions on password reset and account deletion' do
    sign_in
    user.update!(password_digest: BCrypt::Password.create('reset123'))
    expect_signed_out
    user.update!(password: 'password123')
    sign_in('1')
    user.destroy!
    expect_signed_out
    restart_browser
    expect_signed_out
  end

  it 'rejects tampered encrypted cookies' do
    sign_in('1')
    cookie = cookies[:remembered_device]
    restart_browser
    cookies[:remembered_device] = "#{cookie}tampered"
    expect_signed_out
  end

  it 'sets host-only HttpOnly SameSite=Lax cookies with a fixed expiry' do
    sign_in('1')
    header = Array(response.headers['set-cookie']).find { |value| value.start_with?('remembered_device=') }
    expect(header).to include('httponly', 'samesite=lax', 'path=/', 'expires=')
    expect(header).not_to include('domain=')
    session_header = Array(response.headers['set-cookie']).find { |value| value.start_with?('_sample_app_session=') }
    expect(session_header).not_to include('expires=')
  end

  it 'marks remembered cookies Secure in production over HTTPS' do
    allow(Rails.env).to receive(:production?).and_return(true)
    https!
    sign_in('1')
    header = Array(response.headers['set-cookie']).find { |value| value.start_with?('remembered_device=') }
    expect(header).to include('secure', 'httponly', 'samesite=lax', 'path=/')
    expect(header).not_to include('domain=')
  end

  it 'rotates the ordinary session id after email authentication and restoration' do
    get login_path
    before_login = request.session.id.to_s
    sign_in('1')
    expect(request.session.id.to_s).not_to eq(before_login)
    restart_browser
    get login_path
    expect(request.session[:user_id]).to eq(user.id)
    expect(request.session.id.to_s).not_to eq(before_login)
  end

  it 'renders unique unchecked accessible choices with explanatory text for each provider' do
    get login_path
    html = Nokogiri::HTML(response.body)
    choices = html.css('.remember-device input[type=checkbox]')
    expect(choices.size).to eq(3)
    choices.each do |choice|
      expect(choice['checked']).to be_nil
      expect(html.at_css("label[for='#{choice['id']}']").text).to eq('Remember this device for 30 days')
      expect(html.at_css("##{choice['aria-describedby']}").text).to include('private device')
    end
  end
end
