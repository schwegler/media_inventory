# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Series response coordination', type: :request do
  let!(:user) do
    User.create!(name: 'Series reader', email: 'series-response@example.com', password: 'password123',
                 confirmed_at: Time.current)
  end
  let!(:show) { TvShow.create!(title: 'Response coordination') }
  let!(:library) { LibraryItem.create!(user: user, item: show) }
  let!(:episode) { show.tv_episodes.create!(name: 'Extra', season: 0, episode: 1) }
  let(:headers) { { 'X-Series-Request' => 'series-owner:1', 'X-Series-Refresh' => 'true' } }

  before { post login_path, params: { session: { email: user.email, password: 'password123' } } }

  def tracking_params
    { series_page: '1', season: '0', tv_episode: { consumed: true, consumed_at: Date.current } }
  end

  it 'acknowledges enhanced tracking only after saving, so the browser can reload its latest filters' do
    2.times do
      patch toggle_watched_tv_episode_path(episode), params: tracking_params, headers: headers, as: :turbo_stream
      expect(response).to have_http_status(:no_content)
      expect(response.headers['X-Series-Request']).to eq('series-owner:1')
      expect(response.headers['X-Series-Refresh']).to eq('true')
      expect(response.body).to be_empty
    end
    expect(user.library_items.where(item: episode, consumed: true).count).to eq(1)
    expect(library.reload).not_to be_consumed
  end

  it 'also refreshes comic issue tracking without changing its saved identity or parent rating' do
    comic = Comic.create!(title: 'Response coordination comic')
    parent = LibraryItem.create!(user: user, item: comic, rating: '4')
    issue = comic.comic_issues.create!(title: 'First', issue_number: 1)
    comic.comic_issues.create!(title: 'Second', issue_number: 2)
    patch toggle_read_comic_issue_path(issue),
          params: { series_page: '1', comic_issue: { consumed: true, consumed_at: Date.current } },
          headers: headers, as: :turbo_stream
    expect(response).to have_http_status(:no_content)
    expect(user.library_items.find_by!(item: issue)).to be_consumed
    expect(parent.reload.rating).to eq('4')
    expect(parent).not_to be_consumed
  end

  it 'retains the existing stream response for ordinary clients and ignores invalid request tags' do
    patch toggle_watched_tv_episode_path(episode), params: tracking_params, as: :turbo_stream
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('target="series-entries"')
    patch toggle_watched_tv_episode_path(episode), params: tracking_params,
                                                   headers: headers.merge('X-Series-Request' => 'not a valid tag'),
                                                   as: :turbo_stream
    expect(response).to have_http_status(:ok)
    expect(response.headers['X-Series-Request']).to be_nil
  end

  it 'tags frame reads without changing their selected season or caching personal results' do
    get tv_show_path(show), params: { season: 0 }, headers: headers.merge('Turbo-Frame' => 'series-entries')
    expect(response).to have_http_status(:ok)
    expect(response.headers['X-Series-Request']).to eq('series-owner:1')
    expect(response.headers['Cache-Control']).to include('private', 'no-store')
    expect(response.body).to include('data-series-request-token="series-owner:1"', 'Extra')
  end

  it 'does not grant tracking permission to another reader through the response headers' do
    other = User.create!(name: 'Other reader', email: 'other-series-response@example.com', password: 'password123',
                         confirmed_at: Time.current)
    post login_path, params: { session: { email: other.email, password: 'password123' } }
    patch toggle_watched_tv_episode_path(episode), params: tracking_params, headers: headers, as: :turbo_stream
    expect(response).to redirect_to(root_path)
    expect(user.library_items.where(item: episode)).to be_empty
    expect(other.library_items.where(item: episode)).to be_empty
  end
end
