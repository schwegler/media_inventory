# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Collections', type: :request do
  describe 'GET /show' do
    let!(:user) do
      User.create!(name: 'Test', email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
    end

    context 'when the user is confirmed' do
      before do
        user.update!(confirmed_at: Time.current)
      end

      let!(:public_album) do
        LibraryItem.create!(user: user, item: Album.find_or_create_by!(title: 'Public Album'), is_public: true,
                            is_collected: true)
      end
      let!(:private_album) do
        LibraryItem.create!(user: user, item: Album.find_or_create_by!(title: 'Private Album'), is_public: false,
                            is_collected: true)
      end

      let!(:public_comic) do
        LibraryItem.create!(user: user, item: Comic.find_or_create_by!(title: 'Public Comic'), is_public: true,
                            is_collected: true)
      end
      let!(:private_comic) do
        LibraryItem.create!(user: user, item: Comic.find_or_create_by!(title: 'Private Comic'), is_public: false,
                            is_collected: true)
      end

      let!(:public_movie) do
        LibraryItem.create!(user: user, item: Movie.find_or_create_by!(title: 'Public Movie'), is_public: true,
                            is_collected: true)
      end
      let!(:private_movie) do
        LibraryItem.create!(user: user, item: Movie.find_or_create_by!(title: 'Private Movie'), is_public: false,
                            is_collected: true)
      end

      let!(:public_tv_show) do
        LibraryItem.create!(user: user, item: TvShow.find_or_create_by!(title: 'Public TV Show'), is_public: true,
                            is_collected: true)
      end
      let!(:private_tv_show) do
        LibraryItem.create!(user: user, item: TvShow.find_or_create_by!(title: 'Private TV Show'), is_public: false,
                            is_collected: true)
      end

      let!(:public_video_game) do
        LibraryItem.create!(user: user, item: VideoGame.find_or_create_by!(title: 'Public Video Game'), is_public: true,
                            is_collected: true)
      end
      let!(:private_video_game) do
        LibraryItem.create!(user: user, item: VideoGame.find_or_create_by!(title: 'Private Video Game'), is_public: false,
                            is_collected: true)
      end

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

        expect(response.body).to include('Public Video Game')
        expect(response.body).not_to include('Private Video Game')
      end
    end

    context 'when the user is unconfirmed' do
      before do
        user.update!(confirmed_at: nil)
      end

      let!(:public_album) do
        LibraryItem.create!(user: user, item: Album.find_or_create_by!(title: 'Public Album'), is_public: true,
                            is_collected: true)
      end

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
