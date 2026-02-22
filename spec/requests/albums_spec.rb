# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Albums', type: :request do # rubocop:disable Metrics/BlockLength
  let!(:user) do
    User.create(name: 'Example User', email: 'user@example.com', password: 'password',
                password_confirmation: 'password')
  end

  describe 'GET /albums' do
    let!(:album1) { Album.create!(title: 'Album 1', artist: 'Artist 1') }
    let!(:album2) { Album.create!(title: 'Album 2', artist: 'Artist 2') }

    it 'returns http success and lists albums' do
      get albums_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Album 1')
      expect(response.body).to include('Album 2')
    end
  end

  describe 'POST /albums' do
    context 'when not logged in' do
      it 'redirects to login' do
        post albums_path, params: { album: { title: 'New Album' } }
        expect(response).to redirect_to(login_path)
      end
    end

    context 'when logged in' do
      before do
        post login_path, params: { session: { email: user.email, password: user.password } }
      end

      it 'creates a new album' do
        expect do
          post albums_path, params: { album: { title: 'New Album' } }
        end.to change(Album, :count).by(1)
        expect(response).to redirect_to(Album.last)
      end

      context 'with invalid parameters' do
        it 'does not create a new album' do
          expect do
            post albums_path, params: { album: { title: '' } }
          end.not_to change(Album, :count)
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include('New Album')
          expect(response.body).to include('Title can&#39;t be blank')
        end
      end
    end
  end

  describe 'GET /albums/:id' do
    let(:album) do
      Album.create!(title: 'Test Album', artist: 'Test Artist', release_year: 2023, genre: 'Rock')
    end

    context 'when the album exists' do
      it 'returns http success and displays album details' do
        get album_path(album)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Test Album')
        expect(response.body).to include('Test Artist')
        expect(response.body).to include('2023')
        expect(response.body).to include('Rock')
      end
    end

    context 'when the album does not exist' do
      it 'returns http not found' do
        get album_path(id: -1)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /albums/new' do
    context 'when not logged in' do
      it 'redirects to login' do
        get new_album_path
        expect(response).to redirect_to(login_path)
      end
    end

    context 'when logged in' do
      before do
        post login_path, params: { session: { email: user.email, password: user.password } }
      end

      it 'returns http success' do
        get new_album_path
        expect(response).to have_http_status(:success)
      end
    end
  end
end
