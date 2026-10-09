# frozen_string_literal: true

require 'rails_helper'
RSpec.describe SteamLibraryImporter do
  let(:user) { User.create!(name: 'Player', email: 'player@example.com', password: 'password123') }
  before do
    ApiConfiguration.create!(source_name: 'SteamWebAPI', media_type: 'VideoGame', is_active: true, access_token: 'test')
  end
  it 'imports stable IDs, separates aggregate time and preserves manually curated ownership and notes' do
    game = VideoGame.create!(title: 'My Portal title')
    game.update_columns(api_id: 'steam_400')
    library = LibraryItem.create!(user: user, item: game, review: 'My private review')
    library.game_copies.create!(platform: 'Xbox', access_method: 'physical', notes: 'Gift')
    stub_request(:get,
                 /IPlayerService/).to_return(body: { response: { game_count: 1,
                                                                 games: [{ appid: 400, name: 'Portal',
                                                                           playtime_forever: 123 }] } }.to_json)
    expect(described_class.call(user, '76561198000000000')).to eq('ready')
    expect(game.reload.title).to eq('My Portal title')
    expect(library.reload.review).to eq('My private review')
    expect(library.game_copies.count).to eq(2)
    expect(library.game_copies.find_by(steam_app_id: '400').imported_playtime_minutes).to eq(123)
    expect(GameSession.count).to eq(0)
    expect(user.steam_library_sync.reload.imported).to eq(1)
  end
  it 'does not delete copies for a private or partial response' do
    library = LibraryItem.create!(user: user, item: VideoGame.create!(title: 'Manual'))
    library.game_copies.create!(platform: 'PC')
    stub_request(:get, /IPlayerService/).to_return(body: { response: {} }.to_json)
    expect(described_class.call(user, '76561198000000000')).to eq('failed')
    expect(library.game_copies.count).to eq(1)
  end
end
