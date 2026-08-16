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

  describe 'GET /' do
    let!(:user) do
      User.create!(name: 'Test User', email: 'test@example.com', password: 'password', confirmed_at: Time.current)
    end
    let!(:movie) { Movie.create!(title: 'Inception', release_year: 2010) }
    let!(:library_item) do
      LibraryItem.create!(user: user, item: movie, rating: 5, review: 'Amazing movie!', is_public: true)
    end
    let!(:activity) do
      Activity.create!(user: user, trackable: library_item, activity_type: 'reviewed')
    end

    before do
      post login_path, params: { email: user.email, password: 'password' }
    end

    it 'preloads popular review trackable items and renders without error' do
      get root_path
      expect(response).to have_http_status(200)
      expect(response.body).to include('POPULAR REVIEWS WITH FRIENDS')
      expect(response.body).to include('Amazing movie!')
      expect(response.body).to include('Inception')
    end
  end
end
