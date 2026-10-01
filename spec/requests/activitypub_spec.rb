# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ActivityPub & WebFinger API', type: :request do
  let!(:user) do
    User.create!(
      name: 'ActUser',
      email: 'act@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end

  describe 'WebFinger endpoint' do
    it 'returns correct JRD payload for local handle' do
      get '/.well-known/webfinger', params: { resource: 'acct:ActUser@example.com' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['subject']).to eq('acct:ActUser@example.com')
      expect(json['links'].first['type']).to eq('application/activity+json')
      expect(json['links'].first['href']).to include("/users/#{user.id}/actor")
    end

    it 'returns 404 for unknown user' do
      get '/.well-known/webfinger', params: { resource: 'acct:nobody@example.com' }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'ActivityPub Actor profile' do
    it 'returns actor profile representation in JSON format' do
      get "/users/#{user.id}/actor"
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/activity+json')
      json = JSON.parse(response.body)
      expect(json['preferredUsername']).to eq('actuser')
      expect(json['type']).to eq('Person')
      expect(json['publicKey']['publicKeyPem']).to eq(user.public_key)
    end
  end

  describe 'ActivityPub Outbox' do
    it 'renders empty collection when there are no reviews' do
      get "/users/#{user.id}/outbox"
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/activity+json')
      json = JSON.parse(response.body)
      expect(json['type']).to eq('OrderedCollection')
      expect(json['totalItems']).to eq(0)
    end

    it 'includes public reviews with escaped html content' do
      movie = Movie.create!(title: '<b>Inception</b>', release_year: 2010)
      user.library_items.create!(
        item: movie,
        is_public: true,
        review: 'Great <script>alert("xss")</script>',
        rating: 5
      )

      get "/users/#{user.id}/outbox"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['totalItems']).to eq(1)
      content = json['orderedItems'].first['object']['content']
      expect(content).to include('&lt;b&gt;Inception&lt;/b&gt;')
      expect(content).to include('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;')
      expect(content).not_to include('<script>')
    end

    it 'excludes private reviews from the outbox' do
      movie = Movie.create!(title: 'Secret Movie', release_year: 2020)
      user.library_items.create!(
        item: movie,
        is_public: false,
        review: 'Private thoughts',
        rating: 3
      )

      get "/users/#{user.id}/outbox"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['totalItems']).to eq(0)
      expect(json['orderedItems']).to be_empty
    end
  end
end
