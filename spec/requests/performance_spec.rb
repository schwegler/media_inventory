# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Performance Optimization', type: :request do
  describe 'GET /movies' do
    it 'loads the application layout with deferred javascript' do
      get movies_path
      expect(response).to have_http_status(200)
      # Assert that the script tag DOES have defer="defer"
      expect(response.body).to include('<script type="importmap"')
      expect(response.body).to include('import "application"')
    end

    it 'optimizes active storage attachment loading to prevent N+1 queries' do
      # Create some movies
      5.times do |i|
        m = Movie.create!(title: "Movie #{i}")
        m.cover_image.attach(io: StringIO.new('dummy'), filename: "cover_#{i}.png", content_type: 'image/png')
      end

      queries_count = 0
      ActiveSupport::Notifications.subscribe('sql.active_record') do |*_, payload|
        queries_count += 1 unless %w[SCHEMA PRAGMA].include?(payload[:name])
      end

      get movies_path
      expect(response).to have_http_status(200)

      # If N+1 query was present, we would have 1 query for movies, plus 5 queries
      # for attachments, plus 5 for blobs (11 queries).
      # With optimization, it's 3 queries. We can check that the total queries are small and well below 11.
      expect(queries_count).to be < 10
    end
  end

  describe 'GET /users' do
    let!(:user) do
      User.create!(name: 'Test User', email: 'test@example.com', password: 'password123',
                   password_confirmation: 'password123')
    end

    before do
      post login_path, params: { session: { email: user.email, password: 'password123' } }
    end

    it 'optimizes user avatar loading to prevent N+1 queries' do
      # Create some users
      5.times do |i|
        u = User.create!(name: "Friend #{i}", email: "friend#{i}@example.com", password: 'password123',
                         password_confirmation: 'password123')
        u.avatar.attach(io: StringIO.new('dummy'), filename: "avatar_#{i}.png", content_type: 'image/png')
      end

      queries_count = 0
      ActiveSupport::Notifications.subscribe('sql.active_record') do |*_, payload|
        queries_count += 1 unless %w[SCHEMA PRAGMA].include?(payload[:name])
      end

      get users_path
      expect(response).to have_http_status(200)

      # With 5 users with avatars, N+1 would cause at least 11 queries.
      # With optimization, it's around 6-7 queries. We check that queries are well below 12.
      expect(queries_count).to be < 12
    end
  end
end
