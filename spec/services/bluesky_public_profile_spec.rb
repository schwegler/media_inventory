# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BlueskyPublicProfile do
  let(:did) { 'did:plc:synthetic-profile' }
  let(:request_stub) do
    stub_request(:get, 'https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile').with(query: { actor: did })
  end

  [500, 404, 302].each do |status|
    it "ignores HTTP #{status} without following redirects" do
      request_stub.to_return(status: status, headers: { 'Location' => 'https://example.test/private' })
      expect(described_class.fetch(did)).to eq({})
    end
  end

  ['invalid JSON', '[]', 'null'].each do |body|
    it "ignores invalid profile payload #{body}" do
      request_stub.to_return(status: 200, body: body)
      expect(described_class.fetch(did)).to eq({})
    end
  end

  [SocketError, Errno::ECONNRESET, OpenSSL::SSL::SSLError].each do |error|
    it "allows login to continue after #{error}" do
      request_stub.to_raise(error)
      expect(described_class.fetch(did)).to eq({})
    end
  end

  it 'ignores malformed optional fields' do
    request_stub.to_return(status: 200, body: { did: did, displayName: [], handle: {} }.to_json)
    expect(described_class.fetch(did)).to eq({})
  end
end
