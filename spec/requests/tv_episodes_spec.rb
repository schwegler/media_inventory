# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TvEpisodes', type: :request do
  let!(:user) do
    User.create!(name: 'Test User', email: 'test@example.com', password: 'password123',
                 password_confirmation: 'password123', confirmed_at: Time.current)
  end
  let!(:tv_show) do
    TvShow.create!(title: '30 Rock')
  end
  let!(:library_item) do
    LibraryItem.create!(user: user, item: tv_show)
  end
  let!(:tv_episode) do
    tv_show.tv_episodes.create!(name: 'Pilot', season: 1, episode: 1)
  end

  before do
    post login_path, params: { session: { email: user.email, password: 'password123' } }
  end

  describe 'PATCH /tv_episodes/:id/toggle_watched' do
    it 'updates watched status successfully' do
      patch toggle_watched_tv_episode_path(tv_episode), params: { tv_episode: { consumed: true } }
      expect(response).to redirect_to(tv_show)
      expect(LibraryItem.find_by(user: user, item: tv_episode).consumed).to be(true)
    end

    context 'when user does not have access to private TV show' do
      let(:other_user) do
        User.create!(name: 'Other User', email: 'other@example.com', password: 'password123', confirmed_at: Time.current)
      end
      let(:private_show) { TvShow.create!(title: 'Private Show') }
      let!(:private_library_item) { LibraryItem.create!(user: other_user, item: private_show, is_public: false) }
      let!(:private_episode) { private_show.tv_episodes.create!(name: 'Secret', season: 1, episode: 1) }

      it 'prevents updating watched status and redirects' do
        patch toggle_watched_tv_episode_path(private_episode), params: { tv_episode: { consumed: true } }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Not authorized')
      end
    end
  end

  describe 'GET /tv_episodes/:id' do
    it 'returns http success and renders the episode page' do
      get tv_episode_path(tv_episode)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Pilot')
    end
  end
end
