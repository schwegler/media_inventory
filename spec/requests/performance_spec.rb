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

  describe 'Landing page fetch_popular_reviews optimization' do
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
      post login_path, params: { session: { email: user.email, password: 'password123' } }
    end

    it 'assigns exactly the activities with non-blank reviews on the landing page' do
      movie = Movie.create!(title: 'Inception')

      # Create library items with and without reviews
      li_with_review = LibraryItem.create!(user: user, item: movie, is_collected: true, review: 'Fantastic!')
      li_without_review = LibraryItem.create!(user: user, item: movie, is_collected: true, rating: '5')

      # Create reviewed activities
      act_with_review = Activity.create!(user: user, trackable: li_with_review, activity_type: 'reviewed')
      act_without_review = Activity.create!(user: user, trackable: li_without_review, activity_type: 'reviewed')

      get root_path

      expect(response).to have_http_status(:ok)
      # Assert popular_reviews are assigned
      popular_reviews = controller.instance_variable_get(:@popular_reviews)
      expect(popular_reviews).to include(act_with_review)
      expect(popular_reviews).not_to include(act_without_review)
    end
  end
end
