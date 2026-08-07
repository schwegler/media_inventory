# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OmniAuthCallbacksController, type: :controller do
  describe '#setup' do
    before do
      allow(Rails.env).to receive(:test?).and_return(false)
    end

    context 'when mastodon_server is blank' do
      it 'responds with 400 and does not leak raw parameters in the error response' do
        strategy = double('strategy', name: 'mastodon')
        req = double('request', params: { 'mastodon_server' => '' })
        allow(strategy).to receive(:request).and_return(req)
        request.env['omniauth.strategy'] = strategy

        get :setup, params: { provider: 'mastodon' }
        expect(response.status).to eq(400)
        expect(response.body).to eq('Mastodon server required.')
        expect(response.body).not_to include('params')
        expect(response.body).not_to include('inspect')
      end
    end

    context 'when mastodon_server resolves to an unsafe host' do
      it 'responds with 400 and denies SSRF' do
        strategy = double('strategy', name: 'mastodon')
        req = double('request', params: { 'mastodon_server' => 'http://127.0.0.1' })
        allow(strategy).to receive(:request).and_return(req)
        request.env['omniauth.strategy'] = strategy

        allow(Resolv).to receive(:getaddresses).with('127.0.0.1').and_return(['127.0.0.1'])

        get :setup, params: { provider: 'mastodon' }
        expect(response.status).to eq(400)
        expect(response.body).to eq('Invalid Mastodon server.')
      end
    end

    context 'when mastodon_server is a private subnet IP' do
      it 'responds with 400 and denies SSRF' do
        strategy = double('strategy', name: 'mastodon')
        req = double('request', params: { 'mastodon_server' => 'http://192.168.1.1' })
        allow(strategy).to receive(:request).and_return(req)
        request.env['omniauth.strategy'] = strategy

        allow(Resolv).to receive(:getaddresses).with('192.168.1.1').and_return(['192.168.1.1'])

        get :setup, params: { provider: 'mastodon' }
        expect(response.status).to eq(400)
        expect(response.body).to eq('Invalid Mastodon server.')
      end
    end
  end
end

RSpec.describe MastodonAppRegistration, type: :model do
  describe '.safe_host?' do
    it 'returns true for a public hostname with public IP' do
      allow(Resolv).to receive(:getaddresses).with('mastodon.social').and_return(['1.1.1.1'])
      expect(described_class.safe_host?('mastodon.social')).to be true
    end

    it 'returns false for a private hostname resolving to loopback IP' do
      allow(Resolv).to receive(:getaddresses).with('localhost').and_return(['127.0.0.1'])
      expect(described_class.safe_host?('localhost')).to be false
    end

    it 'returns false for a direct loopback IP' do
      allow(Resolv).to receive(:getaddresses).with('127.0.0.1').and_return(['127.0.0.1'])
      expect(described_class.safe_host?('127.0.0.1')).to be false
    end

    it 'returns false for private network IP addresses' do
      allow(Resolv).to receive(:getaddresses).with('192.168.1.100').and_return(['192.168.1.100'])
      expect(described_class.safe_host?('192.168.1.100')).to be false
    end

    it 'returns false when DNS resolution fails' do
      allow(Resolv).to receive(:getaddresses).with('nonexistent.local').and_raise(StandardError.new('DNS error'))
      expect(described_class.safe_host?('nonexistent.local')).to be false
    end
  end
end
