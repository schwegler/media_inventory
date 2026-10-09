# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'In Progress Tracking and Logging', type: :request do
  let!(:user) do
    User.create!(name: 'Jane Doe', username: 'janedoe', email: 'jane@example.com',
                 password: 'password123', password_confirmation: 'password123', confirmed_at: Time.current)
  end

  let!(:other_user) do
    User.create!(name: 'John Smith', username: 'johnsmith', email: 'john@example.com',
                 password: 'password123', password_confirmation: 'password123', confirmed_at: Time.current)
  end

  let!(:tv_show) { TvShow.create!(title: 'Severance') }
  let!(:show_lib) { LibraryItem.create!(user: user, item: tv_show, is_public: true) }
  let!(:ep1) { tv_show.tv_episodes.create!(name: 'Good News About Hell', season: 1, episode: 1) }
  let!(:ep2) { tv_show.tv_episodes.create!(name: 'Half Loop', season: 1, episode: 2) }
  let!(:ep3) { tv_show.tv_episodes.create!(name: 'In Perpetuity', season: 1, episode: 3) }

  let!(:comic) { Comic.create!(title: 'East of West') }
  let!(:comic_lib) { LibraryItem.create!(user: user, item: comic, is_public: true) }
  let!(:iss1) { comic.comic_issues.create!(issue_number: 1, title: 'The Promise') }
  let!(:iss2) { comic.comic_issues.create!(issue_number: 2, title: 'The Message') }

  before do
    # User has started watching Severance and reading East of West
    LibraryItem.create!(user: user, item: ep1, consumed: true, consumed_at: Date.current)
    LibraryItem.create!(user: user, item: iss1, consumed: true, consumed_at: Date.current)
  end

  describe 'GET /users/:id (Profile Overview tab)' do
    context 'when owner is logged in' do
      before do
        post login_path, params: { session: { email: user.email, password: 'password123' } }
      end

      it 'renders the In progress section with next episode and next issue with quick logging buttons' do
        get user_path(user)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('In progress')
        expect(response.body).to include('Severance')
        expect(response.body).to include('Half Loop')
        expect(response.body).to include('East of West')
        expect(response.body).to include('The Message')
        expect(response.body).to include('✓ Watch')
        expect(response.body).to include('✓ Read')
      end
    end

    context 'when a visitor views the public profile' do
      before do
        post login_path, params: { session: { email: other_user.email, password: 'password123' } }
      end

      it 'shows in-progress items but without quick logging buttons' do
        get user_path(user)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('In progress')
        expect(response.body).to include('Severance')
        expect(response.body).to include('Half Loop')
        expect(response.body).not_to include('✓ Watch')
      end

      it 'hides private in-progress items from visitors' do
        show_lib.update!(is_public: false)
        get user_path(user)
        expect(response.body).not_to include('Severance')
        expect(response.body).to include('East of West')
      end
    end
  end

  describe 'Quick logging TV episodes from in-progress' do
    before do
      post login_path, params: { session: { email: user.email, password: 'password123' } }
    end

    it 'logs the next episode via HTML and redirects' do
      patch toggle_watched_tv_episode_path(ep2),
            params: { in_progress: true, tv_episode: { consumed: true, consumed_at: Date.current.to_s, rating: '4.5' } }

      expect(response).to redirect_to(tv_show)
      expect(LibraryItem.find_by(user: user, item: ep2).consumed).to be(true)
      expect(LibraryItem.find_by(user: user, item: ep2).rating).to eq('4.5')
    end

    it 'logs the next episode via Turbo Stream and replaces the card with ep3' do
      patch toggle_watched_tv_episode_path(ep2),
            headers: { 'Accept' => 'text/vnd.turbo-stream.html' },
            params: { in_progress: true, tv_episode: { consumed: true, consumed_at: Date.current.to_s } }

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('turbo-stream action="replace"')
      expect(response.body).to include("in_progress_tv_show_#{tv_show.id}")
      expect(response.body).to include('In Perpetuity')
    end

    it 'removes the card via Turbo Stream when the final episode is watched' do
      LibraryItem.create!(user: user, item: ep2, consumed: true, consumed_at: Date.current)

      patch toggle_watched_tv_episode_path(ep3),
            headers: { 'Accept' => 'text/vnd.turbo-stream.html' },
            params: { in_progress: true, tv_episode: { consumed: true, consumed_at: Date.current.to_s } }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('turbo-stream action="remove"')
      expect(response.body).to include("in_progress_tv_show_#{tv_show.id}")
    end
  end

  describe 'Quick logging Comic issues from in-progress' do
    before do
      post login_path, params: { session: { email: user.email, password: 'password123' } }
    end

    it 'logs the next issue via HTML and redirects' do
      patch toggle_read_comic_issue_path(iss2),
            params: { in_progress: true, comic_issue: { consumed: true, consumed_at: Date.current.to_s, rating: '5.0' } }

      expect(response).to redirect_to(comic)
      expect(LibraryItem.find_by(user: user, item: iss2).consumed).to be(true)
      expect(LibraryItem.find_by(user: user, item: iss2).rating).to eq('5.0')
    end

    it 'removes the comic card via Turbo Stream when the final issue is read' do
      patch toggle_read_comic_issue_path(iss2),
            headers: { 'Accept' => 'text/vnd.turbo-stream.html' },
            params: { in_progress: true, comic_issue: { consumed: true, consumed_at: Date.current.to_s } }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('turbo-stream action="remove"')
      expect(response.body).to include("in_progress_comic_#{comic.id}")
    end
  end
end
