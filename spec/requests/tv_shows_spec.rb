# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'TvShows', type: :request do
  describe 'GET /tv_shows' do
    it 'works! (now write some real specs)' do
      get tv_shows_path
      expect(response).to have_http_status(200)
    end

    it 'displays pagination' do
      26.times { |i| TvShow.create!(title: "Show #{i}", season: 1, episode: 1, network: 'Net') }
      get tv_shows_path
      expect(response).to have_http_status(200)
      expect(response.body).to include('page=2')
    end
  end

  describe 'GET /tv_shows/new' do
    context 'when not logged in' do
      it 'redirects to login' do
        get new_tv_show_path
        expect(response).to redirect_to(login_path)
      end
    end

    context 'when logged in' do
      let(:user) do
        User.create(name: 'Example User', email: 'user@example.com', password: 'password',
                    password_confirmation: 'password')
      end

      before do
        post login_path, params: { session: { email: user.email, password: user.password } }
      end

      it 'returns http success' do
        get new_tv_show_path
        expect(response).to have_http_status(200)
        expect(response.body).to include('New TV Show')
        expect(response.body).to include('name="tv_show[title]"')
        expect(response.body).to include('name="tv_show[season]"')
        expect(response.body).to include('name="tv_show[episode]"')
        expect(response.body).to include('name="tv_show[network]"')
      end
    end
  end

  describe 'GET /tv_shows/:id' do
    it 'returns http success and displays the title' do
      tv_show = TvShow.create!(title: 'Breaking Bad')
      get tv_show_path(tv_show)
      expect(response).to have_http_status(200)
      expect(response.body).to include('Breaking Bad')
    end
  end

  describe 'POST /tv_shows' do
    context 'when not logged in' do
      it 'redirects to login' do
        post tv_shows_path, params: { tv_show: { title: 'New Show' } }
        expect(response).to redirect_to(login_path)
      end
    end

    context 'when logged in' do
      let(:user) do
        User.create(name: 'Example User', email: 'user@example.com', password: 'password',
                    password_confirmation: 'password')
      end

      before do
        post login_path, params: { session: { email: user.email, password: user.password } }
      end

      it 'creates a new tv_show' do
        expect do
          post tv_shows_path, params: { tv_show: { title: 'New Show' } }
        end.to change(TvShow, :count).by(1)
        expect(response).to redirect_to(TvShow.last)
      end

      context 'with invalid parameters' do
        it 'does not create a new TvShow' do
          expect do
            post tv_shows_path, params: { tv_show: { title: '' } }
          end.to_not change(TvShow, :count)
        end

        it 'renders a response with 422 status' do
          post tv_shows_path, params: { tv_show: { title: '' } }
          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      it 'displays an error message' do
        post tv_shows_path, params: { tv_show: { title: '' } }
        expect(response.body).to include('Title can&#39;t be blank')
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
