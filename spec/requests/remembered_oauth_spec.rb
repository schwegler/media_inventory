# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OAuth remembered sign-in', type: :request do
  around do |example|
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:mastodon] = OmniAuth::AuthHash.new(
      provider: 'mastodon', uid: 'synthetic-remembered', info: { nickname: 'Synthetic OAuth' },
      credentials: { token: 'synthetic-provider-token', refresh_token: 'synthetic-refresh-token' },
      extra: { server: 'example.test' }
    )
    OmniAuth.config.mock_auth[:atproto] = OmniAuth::AuthHash.new(
      provider: 'atproto', uid: 'did:plc:synthetic-remembered', info: { nickname: 'synthetic.example.test' },
      credentials: { token: 'synthetic-provider-token', refresh_token: 'synthetic-refresh-token' }
    )
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:mastodon)
    OmniAuth.config.mock_auth.delete(:atproto)
  end

  def oauth_sign_in(provider, remember = nil)
    get login_path
    token = Nokogiri::HTML(response.body).at_css("form[action='/auth/#{provider}'] input[name=authenticity_token]")['value']
    original_session_id = request.session.id.to_s
    was_signed_in = request.session[:user_id].present?
    post "/auth/#{provider}", params: { authenticity_token: token, remember_device: remember }
    expect(response).to redirect_to("/auth/#{provider}/callback")
    follow_redirect!
    expect(response).to redirect_to(root_path)
    expect(request.session.id.to_s).not_to eq(original_session_id) unless was_signed_in
  end

  it 'rejects initiation without CSRF verification and creates no device' do
    post '/auth/mastodon', params: { remember_device: '1' }
    expect(response).to redirect_to(%r{auth/failure})
    expect(RememberedDevice.count).to eq(0)
  end

  %w[mastodon atproto].each do |provider|
    it "remembers opted-in #{provider} sign-in with an independent credential and restores without a provider token" do
      oauth_sign_in(provider, '1')
      expect(RememberedDevice.count).to eq(1)
      expect(RememberedDevice.first.token_digest).not_to eq(Digest::SHA256.hexdigest('synthetic-provider-token'))
      cookies.delete('_sample_app_session')
      get edit_user_path(RememberedDevice.first.user)
      expect(response).to have_http_status(:ok)
    end

    it "keeps unchecked #{provider} sign-in ephemeral" do
      oauth_sign_in(provider)
      expect(RememberedDevice.count).to eq(0)
      expect(cookies[:remembered_device]).to be_blank
    end

    it "ignores #{provider} callback opt-in parameters without authenticated request-phase consent" do
      get "/auth/#{provider}/callback", params: { remember_device: '1' }
      expect(response).to redirect_to(root_path)
      expect(RememberedDevice.count).to eq(0)
    end

    it "does not create persistence while linking #{provider}" do
      user = User.create!(name: 'Link Member', email: 'link@example.test', password: 'password123')
      get login_path
      token = Nokogiri::HTML(response.body).at_css('input[name=authenticity_token]')['value']
      post login_path, params: { authenticity_token: token, session: { email: user.email, password: 'password123' } }
      oauth_sign_in(provider, '1')
      expect(RememberedDevice.count).to eq(0)
      get edit_user_path(user)
      expect(response).to have_http_status(:ok)
    end
  end
end
