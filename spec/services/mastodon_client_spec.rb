# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MastodonClient do
  let(:client) { described_class.new(domain: 'mastodon.social', access_token: 'token') }

  describe '#verify_credentials' do
    it 'returns user data' do
      stub_request(:get, 'https://mastodon.social/api/v1/accounts/verify_credentials')
        .with(headers: { 'Authorization' => 'Bearer token' })
        .to_return(status: 200, body: '{"id": "1"}', headers: { 'Content-Type' => 'application/json' })

      expect(client.verify_credentials['id']).to eq('1')
    end
  end
end
