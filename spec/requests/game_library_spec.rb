# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Personal game library', type: :request do
  let(:user) { User.create!(name: 'Player', email: 'player@example.com', password: 'password123') }
  let(:other) { User.create!(name: 'Other', email: 'other@example.com', password: 'password123') }
  let(:portal) { VideoGame.create!(title: 'Portal', game_type: 'game', metadata_details: { genres: ['Puzzle'] }) }
  let(:halo) { VideoGame.create!(title: 'Halo', game_type: 'game') }
  let(:private_game) { VideoGame.create!(title: 'Other library game') }
  let!(:portal_library) { LibraryItem.create!(user: user, item: portal, rating: '4.5', created_at: 2.days.ago) }
  let!(:halo_library) { LibraryItem.create!(user: user, item: halo, created_at: 1.day.ago) }
  let!(:foreign_library) { LibraryItem.create!(user: other, item: private_game) }

  before do
    post login_path, params: { session: { email: user.email, password: 'password123' } }
    portal_library.game_copies.create!(platform: 'Windows', storefront: 'Steam', imported_playtime_minutes: 180)
    portal_library.game_copies.create!(platform: 'Nintendo Switch', storefront: 'Nintendo', access_method: 'physical')
    halo_library.game_copies.create!(platform: 'Xbox Series X', access_method: 'subscription')
    foreign_library.game_copies.create!(platform: 'Secret platform')
  end

  it 'filters matching copies together and never pulls in another users records' do
    get video_games_path, params: { library: 'mine', platform: 'Nintendo Switch', storefront: 'Steam' }
    expect(response.body).to include('No games match this view')
    get video_games_path, params: { library: 'mine', platform: 'Nintendo Switch', access_method: 'physical' }
    expect(response.body).to include('Portal')
    expect(response.body).not_to include('>Halo<', 'Other library game', 'Secret platform')
    get video_games_path, params: { library: 'mine', genre: 'puzzle' }
    expect(response.body).to include('Portal')
    expect(response.body).not_to include('>Halo<')
  end

  it 'separates imported playtime and subscription access from recorded time and permanent ownership' do
    completed = portal_library.game_playthroughs.create!(status: 'completed', completed_on: Date.current)
    halo_library.game_playthroughs.create!(status: 'currently_playing')
    completed.game_sessions.create!(started_at: Time.zone.parse('2026-01-01 12:00'),
                                    ended_at: Time.zone.parse('2026-01-01 13:00'))
    stats = GameLibraryStatistics.call(user)
    expect(stats).to include(unique_games: 2, owned_copies: 2, subscription_access: 1, completed: 1,
                             currently_playing: 1, completion_rate: 50.0, imported_minutes: 180)
    expect(stats[:recorded_minutes]).to be_within(0.01).of(60)
    expect(stats[:completed_by_year]).to eq(Date.current.year => 1)
    get video_games_path, params: { library: 'mine', layout: 'table', sort: 'playtime' }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Recorded time', '1h 0m', 'Imported lifetime time')
    expect(response.body.index('>Portal<')).to be < response.body.index('>Halo<')
  end

  it 'saves working filters and layout with user-scoped retrieval and deletion' do
    post game_library_views_path,
         params: { name: 'Puzzle table', filters: { genre: 'Puzzle', layout: 'table', sort: 'title', user_id: other.id } }
    expect(response).to have_http_status(:see_other)
    view = user.game_library_views.last
    expect(view.filters).to eq('genre' => 'Puzzle', 'layout' => 'table', 'sort' => 'title')
    get video_games_path, params: { view: view.id }
    expect(response.body).to include('game-library-table', '>Portal<')
    expect(response.body).not_to include('>Halo<')
    post login_path, params: { session: { email: other.email, password: 'password123' } }
    get video_games_path, params: { view: view.id }
    expect(response).to have_http_status(:not_found)
    delete game_library_view_path(view)
    expect(response).to have_http_status(:not_found)
    expect(view.reload).to be_present
  end

  it 'sorts by this users date added and keeps personal controls out of public catalog views' do
    get video_games_path, params: { library: 'mine', sort: 'added', layout: 'list' }
    expect(response.body.index('>Halo<')).to be < response.body.index('>Portal<')
    get video_games_path
    expect(response.body).not_to include('Imported lifetime time', 'Secret platform', 'Save this collection view')
    delete logout_path
    get video_games_path, params: { library: 'mine' }
    expect(response).to redirect_to(login_path)
  end
  it 'renders JSON-rich catalog records once when multiple copies and runs match' do
    portal.update!(metadata_details: { genres: ['Puzzle'], platforms: [{ name: 'PC' }] })
    portal_library.game_copies.create!(platform: 'Linux', storefront: 'Steam')
    2.times { portal_library.game_playthroughs.create!(status: 'currently_playing') }
    portal_library.update!(game_tags: ['puzzle'])
    entries = GameLibraryQuery.new({ play_status: 'currently_playing', storefront: 'Steam', tag: 'puzzle', sort: 'title' },
                                   user: user).call
    expect(entries.map(&:id)).to eq([portal.id])
    expect(entries.first.metadata_details).to include('genres' => ['Puzzle'])
    catalog = GameLibraryQuery.new({ sort: 'title' }).call
    expect(catalog.map(&:id)).to eq([halo.id, private_game.id, portal.id])
    get video_games_path, params: { library: 'mine', play_status: 'currently_playing', tag: 'puzzle' }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Portal')
  end
end
