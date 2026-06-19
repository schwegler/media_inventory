# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BlueskyService do
  let(:user) do
    User.create!(
      name: 'Test User',
      email: 'testuser@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      bsky_handle: 'test.bsky.social',
      bsky_app_password: 'xxxx-xxxx-xxxx-xxxx',
      confirmed_at: Time.current
    )
  end

  let(:trackable) do
    double('Trackable', title: 'The Matrix', rating: '5', review: 'Incredible movie!')
  end

  describe '#post' do
    let(:session_response) do
      res = double('HTTPResponse')
      allow(res).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(res).to receive(:body).and_return({ did: 'did:plc:123', accessJwt: 'jwt123' }.to_json)
      res
    end

    let(:record_response) do
      res = double('HTTPResponse')
      allow(res).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      res
    end

    before do
      allow(Net::HTTP).to receive(:start).and_return(session_response, record_response)
    end

    it 'creates a session and posts a record' do
      service = BlueskyService.new(user.bsky_handle, user.bsky_app_password)
      expect(service.post('Hello, Bluesky!')).to be_truthy
    end
  end
end
