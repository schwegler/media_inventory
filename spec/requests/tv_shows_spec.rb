# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'TvShows', type: :request do
  describe 'GET /tv_shows' do
    it 'works! (now write some real specs)' do
      get tv_shows_path
      expect(response).to have_http_status(200)
    end

    it 'displays pagination' do
      26.times { |i| TvShow.create!(title: "Show #{i}", network: 'Net') }
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
        User.create(name: 'Example User', email: 'user@example.com', password: 'password123',
                    password_confirmation: 'password123')
      end

      before do
        post login_path, params: { session: { email: user.email, password: 'password123' } }
      end

      it 'returns http success' do
        get new_tv_show_path
        expect(response).to have_http_status(200)
        expect(response.body).to include('Log TV Show')
        expect(response.body).to include('name="tv_show[title]"')
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
        User.create(name: 'Example User', email: 'user@example.com', password: 'password123',
                    password_confirmation: 'password123')
      end

      before do
        post login_path, params: { session: { email: user.email, password: 'password123' } }
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

  describe 'PATCH /tv_shows/:id/seasons/:season/mark_watched' do
    let(:tv_show) { TvShow.create!(title: 'Fargo') }
    let!(:s1e1) { tv_show.tv_episodes.create!(name: 'The Crocodile Dilemma', season: 1, episode: 1) }
    let!(:s1e2) { tv_show.tv_episodes.create!(name: 'Rooster Prince', season: 1, episode: 2) }
    let!(:s2e1) { tv_show.tv_episodes.create!(name: 'Waiting for Dutch', season: 2, episode: 1) }

    context 'when not logged in' do
      it 'redirects to login' do
        patch mark_season_watched_tv_show_path(tv_show, season: 1)
        expect(response).to redirect_to(login_path)
      end
    end

    context 'when logged in' do
      let(:user) do
        User.create!(name: 'Viewer', email: 'viewer@example.com', password: 'password123',
                     password_confirmation: 'password123')
      end

      before do
        post login_path, params: { session: { email: user.email, password: 'password123' } }
      end

      it 'marks all episodes of the specified season as watched' do
        patch mark_season_watched_tv_show_path(tv_show, season: 1)

        expect(response).to redirect_to(tv_show)
        expect(user.library_items.find_by(item: s1e1)&.consumed).to be(true)
        expect(user.library_items.find_by(item: s1e2)&.consumed).to be(true)
        expect(user.library_items.find_by(item: s2e1)&.consumed).to be_falsey
      end

      it 'marks the series watched when all seasons are completed' do
        patch mark_season_watched_tv_show_path(tv_show, season: 1)
        expect(user.library_items.find_by(item: tv_show)&.consumed).to be_falsey

        patch mark_season_watched_tv_show_path(tv_show, season: 2)
        expect(user.library_items.find_by(item: tv_show)&.consumed).to be(true)
      end

      it 'unmarks all episodes of the specified season with consumed: false' do
        patch mark_season_watched_tv_show_path(tv_show, season: 1)
        expect(user.library_items.find_by(item: s1e1)&.consumed).to be(true)

        patch mark_season_watched_tv_show_path(tv_show, season: 1), params: { consumed: false }
        expect(user.library_items.find_by(item: s1e1)&.consumed).to be(false)
        expect(user.library_items.find_by(item: s1e2)&.consumed).to be(false)
      end

      it 'redirects back on GET fallback' do
        get "/tv_shows/#{tv_show.id}/seasons/1/mark_watched"
        expect(response).to redirect_to(tv_show_path(tv_show))
      end
    end
  end

  describe 'marking series watched via PATCH /tv_shows/:id' do
    let(:tv_show) { TvShow.create!(title: 'Severance') }
    let!(:ep1) { tv_show.tv_episodes.create!(name: 'Good News About Hell', season: 1, episode: 1) }
    let!(:ep2) { tv_show.tv_episodes.create!(name: 'Half Loop', season: 1, episode: 2) }
    let(:user) do
      User.create!(name: 'Mark S', email: 'marks@example.com', password: 'password123',
                   password_confirmation: 'password123')
    end

    before do
      post login_path, params: { session: { email: user.email, password: 'password123' } }
    end

    it 'marks all episodes watched when the series is marked watched' do
      patch tv_show_path(tv_show), params: { tv_show: { consumed: true } }

      expect(response).to redirect_to(tv_show)
      expect(user.library_items.find_by(item: tv_show)&.consumed).to be(true)
      expect(user.library_items.find_by(item: ep1)&.consumed).to be(true)
      expect(user.library_items.find_by(item: ep2)&.consumed).to be(true)
    end

    it 'renders season watched actions and tallies in the UI' do
      get tv_show_path(tv_show)
      expect(response.body).to include('Mark season watched')
      expect(response.body).to include('0</strong> of <strong>2</strong> watched')

      patch mark_season_watched_tv_show_path(tv_show, season: 1)
      get tv_show_path(tv_show)
      expect(response.body).to include('Undo season')
      expect(response.body).to include('2</strong> of <strong>2</strong> watched')
      expect(response.body).to include('Season 1')
    end
  end
end
