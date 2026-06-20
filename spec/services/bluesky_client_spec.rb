# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BlueskyClient do
  let(:client) { described_class.new(user_id: 1) }

  describe '#resolve_handle' do
    it 'returns did' do
      stub_request(:get, 'https://bsky.social/xrpc/com.atproto.identity.resolveHandle?handle=test.bsky.social')
        .to_return(status: 200, body: '{"did": "did:plc:123"}', headers: { 'Content-Type' => 'application/json' })

      expect(described_class.new(user_id: 1).resolve_handle('test.bsky.social')).to eq('did:plc:123')
    end
  end
end
