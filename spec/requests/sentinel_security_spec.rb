# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sentinel Security Safeguards', type: :request do
  let!(:user) do
    User.create!(
      name: 'Sentinel User',
      email: 'sentinel@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      username: 'sentinel_user',
      confirmed_at: Time.current
    )
  end

  describe 'Mastodon App Registration (SSRF Prevention)' do
    it 'allows valid public hostnames' do
      allow(Resolv).to receive(:getaddresses).with('mastodon.social').and_return(['1.1.1.1'])
      expect(MastodonAppRegistration.safe_host?('mastodon.social')).to be(true)
    end

    it 'blocks loopback and private IP hostnames' do
      allow(Resolv).to receive(:getaddresses).with('localhost').and_return(['127.0.0.1'])
      expect(MastodonAppRegistration.safe_host?('localhost')).to be(false)

      allow(Resolv).to receive(:getaddresses).with('127.0.0.1').and_return(['127.0.0.1'])
      expect(MastodonAppRegistration.safe_host?('127.0.0.1')).to be(false)

      allow(Resolv).to receive(:getaddresses).with('192.168.1.1').and_return(['192.168.1.1'])
      expect(MastodonAppRegistration.safe_host?('192.168.1.1')).to be(false)

      allow(Resolv).to receive(:getaddresses).with('10.0.0.1').and_return(['10.0.0.1'])
      expect(MastodonAppRegistration.safe_host?('10.0.0.1')).to be(false)
    end
  end

  describe 'OmniAuth callbacks parameters protection' do
    before do
      # Allow entering OmniAuthCallbacksController#setup by overriding Rails.env.test? check
      allow(Rails.env).to receive(:test?).and_return(false)
    end

    it 'fails cleanly without reflecting request parameters or keys in the error body' do
      strategy = double('strategy', request: double('request', params: { 'malicious_param' => 'leak_value' }),
                                    name: 'mastodon')

      post '/auth/mastodon/setup', env: { 'omniauth.strategy' => strategy }

      expect(response.status).to eq(400)
      expect(response.body).to include('Mastodon server required.')
      expect(response.body).not_to include('inspect')
      expect(response.body).not_to include('req.params')
      expect(response.body).not_to include('malicious_param')
      expect(response.body).not_to include('leak_value')
    end

    it 'blocks unsafe loopback/private Mastodon servers' do
      strategy = double('strategy', request: double('request', params: { 'mastodon_server' => 'http://127.0.0.1' }),
                                    name: 'mastodon')

      post '/auth/mastodon/setup', env: { 'omniauth.strategy' => strategy }

      expect(response.status).to eq(400)
      expect(response.body).to include('Invalid Mastodon server.')
    end
  end

  describe 'InventoryController sensitive parameter logging' do
    it 'does not log debug parameters during resource creation' do
      # Verify by inspecting the source file that the debug log statement is completely removed
      controller_file = Rails.root.join('app/controllers/inventory_controller.rb').read
      expect(controller_file).not_to include('DEBUG CREATE PARAMS')
    end
  end
end
