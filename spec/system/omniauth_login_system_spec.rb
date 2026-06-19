# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OmniAuth Logins', type: :system do
  before do
    OmniAuth.config.test_mode = true

    # Mock Mastodon
    OmniAuth.config.mock_auth[:mastodon] = OmniAuth::AuthHash.new({
                                                                    provider: 'mastodon',
                                                                    uid: '12345',
                                                                    info: { nickname: 'mastouser',
                                                                            email: 'masto@example.com' },
                                                                    credentials: { token: 'mock_token',
                                                                                   refresh_token: 'mock_refresh' },
                                                                    extra: { server: 'mastodon.social' }
                                                                  })

    # Mock Bluesky
    OmniAuth.config.mock_auth[:atproto] = OmniAuth::AuthHash.new({
                                                                   provider: 'atproto',
                                                                   uid: 'did:plc:12345',
                                                                   info: { nickname: 'blueskyuser.bsky.social',
                                                                           email: nil },
                                                                   credentials: { token: 'mock_token',
                                                                                  refresh_token: 'mock_refresh' }
                                                                 })
    # Mock Mastodon Registration
    dummy_app = Struct.new(:client_id, :client_secret, :server).new('dummy_id', 'dummy_secret', 'mastodon.social')
    allow(MastodonAppRegistration).to receive(:register).and_return(dummy_app)

    # Mock Bluesky Registration/Metadata setup
    allow_any_instance_of(OmniAuthCallbacksController).to receive(:setup_atproto) do |controller|
      controller.request.env['omniauth.strategy'].request
      controller.request.env['omniauth.strategy'].options.client_id = 'dummy_client_id'
      controller.render plain: 'Setup complete', status: 404
    end
  end

  after do
    OmniAuth.config.test_mode = false
  end

  it 'logs in with Mastodon' do
    visit login_path
    click_button 'Mastodon'
    fill_in 'Mastodon Server URL', with: 'mastodon.social'
    click_button 'Log in via Mastodon'

    expect(page).to have_content('Successfully connected to Mastodon!')
    expect(page).to have_content('Welcome back')
  end

  it 'logs in with Bluesky' do
    visit login_path
    click_button 'Bluesky', exact: true
    fill_in 'Bluesky Handle', with: 'blueskyuser.bsky.social', match: :first
    click_button 'Log in via Bluesky'

    expect(page).to have_content('Successfully connected to Bluesky!')
    expect(page).to have_content('Welcome back')
  end
end
