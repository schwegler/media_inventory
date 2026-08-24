# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MastodonAppRegistration do
  describe '.safe_host?' do
    it 'returns true for public hostnames' do
      allow(Resolv).to receive(:getaddresses).with('mastodon.social').and_return(['1.1.1.1'])
      expect(described_class.safe_host?('mastodon.social')).to be true
    end

    it 'returns false for loopback IP address' do
      allow(Resolv).to receive(:getaddresses).with('localhost').and_return(['127.0.0.1'])
      expect(described_class.safe_host?('localhost')).to be false
    end

    it 'returns false for private IP address range' do
      allow(Resolv).to receive(:getaddresses).with('internal.local').and_return(['10.0.0.1'])
      expect(described_class.safe_host?('internal.local')).to be false
    end

    it 'returns false for link-local IP address range' do
      allow(Resolv).to receive(:getaddresses).with('metadata.local').and_return(['169.254.169.254'])
      expect(described_class.safe_host?('metadata.local')).to be false
    end

    it 'returns false when resolution fails' do
      allow(Resolv).to receive(:getaddresses).and_raise(Resolv::ResolvError)
      expect(described_class.safe_host?('invalid.domain')).to be false
    end
  end

  describe '.register' do
    it 'prevents registration calls for unsafe hosts' do
      allow(described_class).to receive(:safe_host?).with('127.0.0.1').and_return(false)
      expect(Net::HTTP).not_to receive(:start)

      result = described_class.register('127.0.0.1', 'https://example.com/callback')
      expect(result).to be_nil
    end

    it 'allows registration for safe hosts' do
      allow(described_class).to receive(:safe_host?).with('mastodon.social').and_return(true)
      stub_request(:post, 'https://mastodon.social/api/v1/apps')
        .to_return(status: 200, body: { client_id: 'cid', client_secret: 'csecret' }.to_json)

      app = described_class.register('mastodon.social', 'https://example.com/callback')
      expect(app).to be_persisted
      expect(app.server).to eq('mastodon.social')
      expect(app.client_id).to eq('cid')
    end
  end
end
