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
      patch toggle_watched_tv_episode_path(tv_episode), params: { tv_episode: { watched: true } }
      expect(response).to redirect_to(tv_show)
      expect(tv_episode.reload.watched).to be(true)
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
