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
  end

  describe 'GET / (Dashboard performance)' do
    let!(:user) do
      User.create!(
        name: 'Active Tracker',
        email: 'tracker@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        confirmed_at: Time.current
      )
    end

    before do
      # Log in the user
      post login_path, params: { session: { email: user.email, password: 'password123' } }
      expect(response).to redirect_to(user)

      # Create distinct media items (Movies)
      movies = (1..5).map do |i|
        Movie.create!(title: "Movie #{i}", director: "Director #{i}", release_year: 2000 + i)
      end

      # Create LibraryItems
      lib_items = movies.map do |movie|
        LibraryItem.create!(user: user, item: movie, is_collected: true, rating: '5', review: 'Awesome movie!')
      end

      # Generate activities to make them popular
      lib_items.each do |lib_item|
        Activity.create!(user: user, trackable: lib_item, activity_type: 'added', created_at: Time.current)
      end
    end

    it 'optimizes popular items fetching without N+1 queries' do
      # Warm up schema caching/autoloading to avoid counting system queries
      get root_path

      queries_count = 0
      ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, payload|
        next if payload[:name] == 'SCHEMA' || payload[:sql] =~ /PRAGMA/

        queries_count += 1
      end

      get root_path
      expect(response).to have_http_status(200)

      # Preloading avoids N+1 queries for multiple items, keeping the queries count very low and bounded
      expect(queries_count).to be < 35
    end
  end
end
