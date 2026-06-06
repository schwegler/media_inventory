# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Collections', type: :request do
  describe 'GET /show' do
    let!(:user) do
      User.create!(name: 'Test', email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
    end

    context 'when the user is confirmed' do
      before do
        user.update!(confirmed_at: Time.current)
      end

      let!(:public_album) { user.albums.create!(title: 'Public Album', is_public: true) }
      let!(:private_album) { user.albums.create!(title: 'Private Album', is_public: false) }

      let!(:public_comic) { user.comics.create!(title: 'Public Comic', is_public: true) }
      let!(:private_comic) { user.comics.create!(title: 'Private Comic', is_public: false) }

      let!(:public_movie) { user.movies.create!(title: 'Public Movie', is_public: true) }
      let!(:private_movie) { user.movies.create!(title: 'Private Movie', is_public: false) }

      let!(:public_tv_show) { user.tv_shows.create!(title: 'Public TV Show', is_public: true) }
      let!(:private_tv_show) { user.tv_shows.create!(title: 'Private TV Show', is_public: false) }

      let!(:public_wrestling_event) { user.wrestling_events.create!(title: 'Public Wrestling Event', is_public: true) }
      let!(:private_wrestling_event) { user.wrestling_events.create!(title: 'Private Wrestling Event', is_public: false) }

      it 'returns http success' do
        get "/collections/#{user.id}"
        expect(response).to have_http_status(:success)
      end

      it 'displays only public collections for the user' do
        get "/collections/#{user.id}"

        expect(response.body).to include('Public Album')
        expect(response.body).not_to include('Private Album')

        expect(response.body).to include('Public Comic')
        expect(response.body).not_to include('Private Comic')

        expect(response.body).to include('Public Movie')
        expect(response.body).not_to include('Private Movie')

        expect(response.body).to include('Public TV Show')
        expect(response.body).not_to include('Private TV Show')

        expect(response.body).to include('Public Wrestling Event')
        expect(response.body).not_to include('Private Wrestling Event')
      end
    end

    context 'when the user is unconfirmed' do
      before do
        user.update!(confirmed_at: nil)
      end

      let!(:public_album) { user.albums.create!(title: 'Public Album', is_public: true) }

      it 'returns http success' do
        get "/collections/#{user.id}"
        expect(response).to have_http_status(:success)
      end

      it 'does not display collections and shows a warning message' do
        get "/collections/#{user.id}"

        expect(response.body).not_to include('Public Album')
        expect(response.body).to include('This user&#39;s collection is not public because their account is unconfirmed.')
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
