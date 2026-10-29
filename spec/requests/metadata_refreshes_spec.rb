# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metadata repair', type: :request do
  include ActiveJob::TestHelper

  around { |example| perform_enqueued_jobs(only: RefreshMediaMetadataJob) { example.run } }
  let(:user) { User.create!(name: 'Reader', email: 'reader@example.com', password: 'password', confirmed_at: Time.current) }
  let(:show) { TvShow.create!(title: 'A custom show title') }
  let(:path) { refresh_metadata_path(media_type: 'tv_shows', media_id: show.id) }

  before do
    show.update_columns(api_id: '42', thumbnail_url: 'https://images.example/dead.jpg')
    stub_request(:get, 'https://api.tvmaze.com/shows/42').to_return(
      body: { name: 'Provider title', image: { original: 'https://images.example/new.jpg' } }.to_json
    )
    stub_request(:get, 'https://api.tvmaze.com/shows/42/episodes?specials=1').to_return(
      body: [{ name: 'Pilot', season: 1, number: 1, airdate: '2026-10-01' }].to_json
    )
  end

  def login
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  it 'rejects anonymous requests without contacting providers' do
    post path
    expect(response).to redirect_to(login_url)
    expect(MetadataRefresh.count).to eq(0)
    expect(WebMock).not_to have_requested(:get, 'https://api.tvmaze.com/shows/42')
  end

  it 'allows normal members to repair public catalog metadata but ignores injected fields' do
    login
    post path, params: { api_id: '999', title: 'Injected', admin: true }
    expect(response).to have_http_status(:see_other)
    expect(response.location).to end_with('#metadata-health')
    follow_redirect!
    expect(Nokogiri::HTML(response.body).at_css('#metadata-health')['open']).not_to be_nil
    expect(show.reload.thumbnail_url).to eq('https://images.example/new.jpg')
    expect(show.title).to eq('A custom show title')
    expect(show.api_id).to eq('42')
    expect(user.reload.admin?).to be false
    expect(show.tv_episodes.count).to eq(1)
  end

  it 'rejects arbitrary classes and admin routes remain restricted' do
    login
    post refresh_metadata_path(media_type: 'users', media_id: user.id)
    expect(response).to have_http_status(:not_found)
    expect(MetadataRefresh.count).to eq(0)
    post update_from_api_admin_tv_show_path(show), params: { api_data: { title: 'Injected' } }
    expect(show.reload.title).to eq('A custom show title')
  end

  it 'blocks repeated clicks before making another provider request' do
    login
    2.times { post path }
    expect(WebMock).to have_requested(:get, 'https://api.tvmaze.com/shows/42').once
    expect(flash[:notice]).to include('wait')
  end

  it 'reports a missing source without erasing artwork' do
    login
    show.update_columns(api_id: nil)
    post path
    expect(show.reload.thumbnail_url).to eq('https://images.example/dead.jpg')
    expect(MetadataRefresh.find_by(item: show).state).to eq('unsupported')
  end

  it 'expires stale refreshing state after lease duration' do
    refresh = MetadataRefresh.create!(item: show, state: 'refreshing', requested_at: 3.minutes.ago)
    expect(refresh.current_state).to eq('failed')

    login
    get tv_show_path(show)
    expect(response.body).to include('data-refresh-state="failed"')
  end

  it 'renders unique disclosure IDs for ownership and review on media show page' do
    album = Album.create!(title: 'Abbey Road', artist: 'The Beatles')
    LibraryItem.create!(user: user, item: album)
    login
    get album_path(album)
    expect(response.body).to include("id=\"ownership-details-#{album.id}\"")
    expect(response.body).to include("id=\"review-details-#{album.id}\"")
  end

  it 'reads a small private status without creating records or contacting providers' do
    status_path = metadata_status_path(media_type: 'tv_shows', media_id: show.id)
    get status_path, as: :json
    expect(response).to redirect_to(login_url)
    login
    expect { get status_path, as: :json }.not_to change(MetadataRefresh, :count)
    expect(response.parsed_body).to eq('state' => 'idle', 'message' => nil, 'request_id' => nil)
    expect(response.headers['Cache-Control']).to include('private', 'no-store')
    refresh = MetadataRefresh.create!(item: show, state: 'refreshing', requested_at: Time.current, provider: 'Secret URL')
    get status_path, as: :json
    expect(response.parsed_body.keys).to match_array(%w[state message request_id])
    expect(response.parsed_body['request_id']).to eq(refresh.requested_at.iso8601(6))
    expect(response.body).not_to include('Secret URL')
    expect(WebMock).not_to have_requested(:get, 'https://api.tvmaze.com/shows/42')
  end

  it 'keeps status authorization aligned with game refresh ownership and fixed media types' do
    login
    game = VideoGame.create!(title: 'Unowned game')
    get metadata_status_path(media_type: 'video_games', media_id: game.id), as: :json
    expect(response).to have_http_status(:forbidden)
    LibraryItem.create!(user: user, item: game)
    get metadata_status_path(media_type: 'video_games', media_id: game.id), as: :json
    expect(response).to have_http_status(:ok)
    get metadata_status_path(media_type: 'users', media_id: user.id), as: :json
    expect(response).to have_http_status(:not_found)
  end
end
