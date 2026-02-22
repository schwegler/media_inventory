# frozen_string_literal: true

require 'spec_helper'
# rubocop:disable Metrics/BlockLength

RSpec.describe 'Comics', type: :request do
  describe 'GET /comics' do
    let!(:comic1) { Comic.create!(title: 'Amazing Spider-Man', issue_number: 1, publisher: 'Marvel') }
    let!(:comic2) { Comic.create!(title: 'Detective Comics', issue_number: 27, publisher: 'DC') }

    it 'returns a successful response' do
      get comics_path
      expect(response).to have_http_status(200)
    end

    it 'includes the comic titles' do
      get comics_path
      expect(response.body).to include('Amazing Spider-Man')
      expect(response.body).to include('Detective Comics')
    end

    context 'with pagination' do
      before do
        Comic.delete_all
        30.times { |i| Comic.create!(title: "Comic #{i}", issue_number: i, publisher: 'Marvel') }
      end

      it 'paginates the results' do
        get comics_path
        expect(response).to have_http_status(200)
        expect(response.body).to include('Comic 0')
        expect(response.body).to include('class="pagination"')
      end
    end
  end

  describe 'GET /comics/new' do
    context 'when not logged in' do
      it 'redirects to login path' do
        get new_comic_path
        expect(response).to redirect_to(login_path)
      end
    end

    context 'when logged in' do
      let(:user) do
        User.create!(name: 'Test User', email: 'test@example.com', password: 'password', password_confirmation: 'password')
      end

      before do
        post login_path, params: { session: { email: user.email, password: user.password } }
      end

      it 'returns a successful response' do
        get new_comic_path
        expect(response).to have_http_status(200)
      end
    end
  end

  describe 'GET /comics/:id' do
    let!(:comic) { Comic.create!(title: 'Batman', issue_number: 1, publisher: 'DC') }

    it 'returns a successful response' do
      get comic_path(comic)
      expect(response).to have_http_status(200)
    end

    it 'includes the comic details' do
      get comic_path(comic)
      expect(response.body).to include('Batman')
      expect(response.body).to include('DC')
    end
  end

  describe 'POST /comics' do
    context 'when not logged in' do
      it 'redirects to login path' do
        post comics_path, params: { comic: { title: 'Unauthorized Comic' } }
        expect(response).to redirect_to(login_path)
      end

      it 'does not create a comic' do
        expect do
          post comics_path, params: { comic: { title: 'Unauthorized Comic' } }
        end.not_to change(Comic, :count)
      end
    end

    context 'when logged in' do
      let(:user) do
        User.create!(name: 'Test User', email: 'test@example.com', password: 'password', password_confirmation: 'password')
      end

      before do
        post login_path, params: { session: { email: user.email, password: user.password } }
      end

      it 'creates a new comic' do
        expect do
          post comics_path, params: { comic: { title: 'Authorized Comic' } }
        end.to change(Comic, :count).by(1)
        expect(response).to redirect_to(Comic.last)
      end

      context 'with invalid parameters' do
        it 'does not create a new comic' do
          expect do
            post comics_path, params: { comic: { title: '' } }
          end.not_to change(Comic, :count)
        end

        it 'renders the new template' do
          post comics_path, params: { comic: { title: '' } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include('New Comic')
          expect(response.body).to include('Title can&#39;t be blank')
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
