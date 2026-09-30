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

    it 'includes public reviews and excludes private reviews while escaping HTML' do
      movie = Movie.create!(title: 'The Matrix <Script>', release_year: 1999)

      public_item = LibraryItem.create!(
        user: user,
        item: movie,
        review: 'Great movie! <script>alert(1)</script>',
        rating: 5,
        is_public: true
      )

      LibraryItem.create!(
        user: user,
        item: movie,
        review: 'Secret review',
        rating: 1,
        is_public: false
      )

      get "/users/#{user.id}/outbox"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['totalItems']).to eq(1)
      note = json['orderedItems'].first['object']

      expect(note['content']).to include('The Matrix &lt;Script&gt;')
      expect(note['content']).to include('Great movie! &lt;script&gt;alert(1)&lt;/script&gt;')
      expect(note['content']).not_to include('Secret review')
      expect(note['id']).to include("/movies/#{movie.id}#review-#{public_item.activities.first.id}")
    end
  end
end
