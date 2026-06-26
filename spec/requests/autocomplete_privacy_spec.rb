# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Autocomplete Privacy', type: :request do
  let(:user_a) { User.create!(name: 'User A', email: 'user_a@example.com', password: 'password', confirmed_at: Time.current) }
  let(:user_b) { User.create!(name: 'User B', email: 'user_b@example.com', password: 'password', confirmed_at: Time.current) }
  let!(:private_movie) { Movie.create!(title: 'Secret Movie Autocomplete') }
  let!(:public_movie) { Movie.create!(title: 'Public Movie Autocomplete') }

  before do
    LibraryItem.create!(user: user_a, item: private_movie, is_public: false)
    LibraryItem.create!(user: user_a, item: public_movie, is_public: true)

    # Stub MediaSearchService to return empty so we only test local results
    allow(MediaSearchService).to receive(:call).and_return([])
  end

  describe 'GET /media/autocomplete' do
    context 'when not logged in' do
      it 'does not include private movies in results' do
        get '/media/autocomplete', params: { q: 'Autocomplete', type: 'movie' }
        expect(response.body).to include('Public Movie Autocomplete')
        expect(response.body).not_to include('Secret Movie Autocomplete')
      end
    end

    context 'when logged in as User B' do
      before { post login_path, params: { session: { email: user_b.email, password: 'password' } } }

      it 'does not include User A private movies in results' do
        get '/media/autocomplete', params: { q: 'Autocomplete', type: 'movie' }
        expect(response.body).to include('Public Movie Autocomplete')
        expect(response.body).not_to include('Secret Movie Autocomplete')
      end
    end

    context 'when logged in as User A' do
      before { post login_path, params: { session: { email: user_a.email, password: 'password' } } }

      it 'includes own private movies in results' do
        get '/media/autocomplete', params: { q: 'Autocomplete', type: 'movie' }
        expect(response.body).to include('Public Movie Autocomplete')
        expect(response.body).to include('Secret Movie Autocomplete')
      end
    end
  end
end
