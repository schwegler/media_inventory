# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sentinel Security Controls', type: :request do
  describe 'Mastodon App Registration (SSRF Prevention)' do
    it 'allows valid public hostnames' do
      expect(MastodonAppRegistration.safe_host?('mastodon.social')).to be(true)
    end

    it 'blocks loopback and private IP hostnames' do
      expect(MastodonAppRegistration.safe_host?('localhost')).to be(false)
      expect(MastodonAppRegistration.safe_host?('127.0.0.1')).to be(false)
      expect(MastodonAppRegistration.safe_host?('192.168.1.1')).to be(false)
      expect(MastodonAppRegistration.safe_host?('10.0.0.1')).to be(false)
    end
  end

  describe 'OmniAuth callbacks parameters protection' do
    it 'does not reflect raw parameters when mastodon_server is blank' do
      allow(Rails.env).to receive(:test?).and_return(false)

      strategy = double('strategy', request: double('request', params: {}), name: 'mastodon')

      post '/auth/mastodon/setup', env: { 'omniauth.strategy' => strategy }

      expect(response.status).to eq(400)
      expect(response.body).to eq('Mastodon server required.')
      expect(response.body).not_to include('inspect')
      expect(response.body).not_to include('req.params')
    end

    it 'blocks unsafe loopback/private Mastodon servers' do
      allow(Rails.env).to receive(:test?).and_return(false)
      strategy = double('strategy', request: double('request', params: { 'mastodon_server' => 'http://127.0.0.1' }), name: 'mastodon')

      post '/auth/mastodon/setup', env: { 'omniauth.strategy' => strategy }

      expect(response.status).to eq(400)
      expect(response.body).to eq('Invalid Mastodon server.')
    end
  end

  describe 'Inventory Controller log params inspection' do
    it 'does not log debug raw params' do
      controller_file = Rails.root.join('app/controllers/inventory_controller.rb').read
      expect(controller_file).not_to include('DEBUG CREATE PARAMS')
    end
  end
end
