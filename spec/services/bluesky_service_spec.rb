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

  describe '.format_message' do
    it 'respects custom templates' do
      msg = BlueskyService.format_message('Just watched [title]!', 'The Matrix', 'consumed', trackable)
      expect(msg).to eq('Just watched The Matrix!')
    end

    it 'uses default added message' do
      msg = BlueskyService.format_message(nil, 'The Matrix', 'added', trackable)
      expect(msg).to eq('Just added The Matrix to my collection!')
    end

    it 'uses default watchlist message' do
      msg = BlueskyService.format_message(nil, 'The Matrix', 'watchlist', trackable)
      expect(msg).to eq('Just added The Matrix to my watchlist.')
    end

    it 'uses default consumed message' do
      msg = BlueskyService.format_message(nil, 'The Matrix', 'consumed', trackable)
      expect(msg).to eq('Just finished watching/reading The Matrix.')
    end

    it 'uses default reviewed message with rating' do
      msg = BlueskyService.format_message(nil, 'The Matrix', 'reviewed', trackable)
      expect(msg).to eq('Just reviewed The Matrix - 5★: Incredible movie!')
    end
  end

  describe '.post_activity' do
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

    it 'posts activity if handle and app password are present' do
      expect(BlueskyService.post_activity(user, 'added', trackable)).to be_truthy
    end

    it 'respects bsky_post_reviews_only preference and skips non-review activity' do
      user.update!(bsky_post_reviews_only: true)
      expect(BlueskyService.post_activity(user, 'added', trackable)).to be_nil
    end

    it 'posts review activity when bsky_post_reviews_only is true' do
      user.update!(bsky_post_reviews_only: true)
      expect(BlueskyService.post_activity(user, 'reviewed', trackable)).to be_truthy
    end
  end
end
