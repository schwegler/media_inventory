# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Game catalog selection', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:user) do
    User.create!(name: 'Collector', email: 'identity@example.test', password: 'password123',
                 password_confirmation: 'password123')
  end
  let!(:game) { VideoGame.create!(title: 'Original title', api_id: 'steam_620', release_year: 2011) }

  before do
    post login_path, params: { session: { email: user.email, password: 'password123' } }
  end

  it 'reuses a known alternate provider identifier and preserves canonical metadata and private histories' do
    game.game_external_ids.create!(provider: 'rawg', external_id: '4200')
    library = LibraryItem.create!(user: user, item: game, review: 'Keep my review')
    copy = library.game_copies.create!(platform: 'PC', access_method: 'digital', ownership_status: 'owned')
    expect do
      post video_games_path, params: { video_game: { title: 'Different provider title', api_id: 'rawg_4200' } }
    end.not_to change(VideoGame, :count)
    expect(response).to redirect_to(game)
    expect(game.reload.title).to eq('Original title')
    expect(game.api_id).to eq('steam_620')
    expect(library.reload.review).to eq('Keep my review')
    expect(library.game_copies.pluck(:id)).to eq([copy.id])
  end

  it 'keeps manually entered same-title releases distinct' do
    expect do
      post video_games_path, params: { video_game: { title: game.title, release_year: 2025 } }
    end.to change(VideoGame, :count).by(1)
    expect(VideoGame.last.release_year).to eq(2025)
    expect(game.reload.release_year).to eq(2011)
  end

  it 'reuses an explicitly selected local game without a provider identifier' do
    game.update!(api_id: nil)
    token = game.signed_id(purpose: 'game-catalog-selection', expires_in: 30.minutes)
    expect do
      post video_games_path, params: { video_game: { title: game.title, catalog_selection: token } }
    end.not_to change(VideoGame, :count)
    expect(response).to redirect_to(game)
    expect(user.library_items.find_by(item: game)).to be_present
  end

  it 'rejects a tampered selection without creating a game or library entry' do
    expect do
      post video_games_path, params: { video_game: { title: 'Invalid', catalog_selection: 'tampered' } }
    end.not_to change(LibraryItem, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Select the game again')
    expect(VideoGame.count).to eq(1)
  end

  it 'rejects conflicting primary and mapped provider identities' do
    other = VideoGame.create!(title: 'Other game', api_id: 'rawg_4200')
    other.game_external_ids.find_by!(provider: 'rawg').update!(video_game: game)
    post video_games_path, params: { video_game: { title: 'Other game', api_id: 'rawg_4200' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Conflicting game identifiers')
    expect(user.library_items).to be_empty
  end

  it 'rejects expired local selections' do
    token = game.signed_id(purpose: 'game-catalog-selection', expires_in: 1.second)
    travel 2.seconds do
      post video_games_path, params: { video_game: { title: game.title, catalog_selection: token } }
    end
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.library_items).to be_empty
  end
end
