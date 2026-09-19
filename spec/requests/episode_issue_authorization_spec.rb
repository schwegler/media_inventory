# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Episode and Issue Authorization', type: :request do
  let(:owner) { User.create!(name: 'Owner', email: 'owner@example.com', password: 'password', username: 'owner') }
  let(:attacker) do
    User.create!(name: 'Attacker', email: 'attacker@example.com', password: 'password', username: 'attacker')
  end

  let(:tv_show) { TvShow.create!(title: 'Private Show') }
  let!(:show_library_item) { LibraryItem.create!(user: owner, item: tv_show, is_collected: true, is_public: false) }
  let!(:tv_episode) { TvEpisode.create!(tv_show: tv_show, name: 'Pilot', season: 1, episode: 1) }

  let(:comic) { Comic.create!(title: 'Private Comic') }
  let!(:comic_library_item) { LibraryItem.create!(user: owner, item: comic, is_collected: true, is_public: false) }
  let!(:comic_issue) { ComicIssue.create!(comic: comic, title: 'Issue 1', issue_number: 1) }

  before do
    post login_path, params: { session: { email: attacker.email, password: 'password' } }
  end

  describe 'PATCH /tv_episodes/:id/toggle_watched' do
    it 'denies access when attacker attempts to toggle episode of private show owned by another user' do
      patch toggle_watched_tv_episode_path(tv_episode), params: { tv_episode: { consumed: true } }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Not authorized')
    end
  end

  describe 'PATCH /comic_issues/:id/toggle_read' do
    it 'denies access when attacker attempts to toggle issue of private comic owned by another user' do
      patch toggle_read_comic_issue_path(comic_issue), params: { comic_issue: { consumed: true } }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Not authorized')
    end
  end
end
