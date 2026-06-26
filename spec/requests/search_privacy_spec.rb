# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Search Privacy', type: :request do
  let(:user_a) { User.create!(name: 'User A', email: 'user_a@example.com', password: 'password', confirmed_at: Time.current) }
  let(:user_b) { User.create!(name: 'User B', email: 'user_b@example.com', password: 'password', confirmed_at: Time.current) }
  let!(:private_movie) { Movie.create!(title: 'Secret Movie') }
  let!(:public_movie) { Movie.create!(title: 'Public Movie') }

  before do
    LibraryItem.create!(user: user_a, item: private_movie, is_public: false)
    LibraryItem.create!(user: user_a, item: public_movie, is_public: true)
  end

  describe 'GET /search' do
    context 'when not logged in' do
      it 'does not show private movies' do
        get search_path, params: { q: 'Movie' }
        expect(response.body).to include('Public Movie')
        expect(response.body).not_to include('Secret Movie')
      end
    end

    context 'when logged in as User B' do
      before { post login_path, params: { session: { email: user_b.email, password: 'password' } } }

      it 'does not show User A private movies' do
        get search_path, params: { q: 'Movie' }
        expect(response.body).to include('Public Movie')
        expect(response.body).not_to include('Secret Movie')
      end
    end

    context 'when logged in as User A' do
      before { post login_path, params: { session: { email: user_a.email, password: 'password' } } }

      it 'shows own private movies' do
        get search_path, params: { q: 'Movie' }
        expect(response.body).to include('Public Movie')
        expect(response.body).to include('Secret Movie')
      end
    end
  end
end
