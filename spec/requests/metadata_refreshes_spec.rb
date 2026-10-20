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
    stub_request(:get, 'https://api.tvmaze.com/shows/42/episodes').to_return(
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

  it 'refreshes a catalog-only Steam game using its prefixed source ID without adding it to a library' do
    login
    game = VideoGame.create!(title: 'PowerWash Simulator', release_year: 2022, developer: 'FuturLab')
    game.update_columns(api_id: 'steam_1290000', thumbnail_url: 'https://images.example/old.jpg')
    endpoint = 'https://store.steampowered.com/api/appdetails?appids=1290000'
    stub_request(:get, endpoint).to_return(body: {
      '1290000' => { success: true, data: { developers: ['FuturLab'], type: 'game',
                                            header_image: 'https://images.example/powerwash.jpg' } }
    }.to_json)
    expect do
      post refresh_metadata_path(media_type: 'video_games', media_id: game.id), as: :turbo_stream
    end.not_to change(LibraryItem, :count)
    expect(response).to have_http_status(:see_other)
    expect(MetadataRefresh.find_by!(item: game).state).to eq('success')
    expect(game.reload.thumbnail_url).to eq('https://images.example/powerwash.jpg')
    expect(game.api_id).to eq('steam_1290000')
    expect(WebMock).to have_requested(:get, endpoint).once
    get metadata_status_path(media_type: 'video_games', media_id: game.id), as: :json
    expect(response.parsed_body['state']).to eq('success')
  end

  it 'allows catalog game status without creating ownership and rejects invalid media types' do
    login
    game = VideoGame.create!(title: 'Unowned game')
    get metadata_status_path(media_type: 'video_games', media_id: game.id), as: :json
    expect(response).to have_http_status(:ok)
    expect(user.library_items.exists?(item: game)).to be false
    LibraryItem.create!(user: user, item: game)
    get metadata_status_path(media_type: 'video_games', media_id: game.id), as: :json
    expect(response).to have_http_status(:ok)
    get metadata_status_path(media_type: 'users', media_id: user.id), as: :json
    expect(response).to have_http_status(:not_found)
  end
end
