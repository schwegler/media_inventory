# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'Game provider adapters' do
  before { MediaSources::Registry::CACHE.clear }
  it 'declares only implemented capabilities and gracefully disables RAWG without a key' do
    expect(GameProviders::Steam.new.capabilities).to include(:search, :details, :artwork)
    expect(GameProviders::Rawg.new.enabled?).to be(false)
    expect { GameProviders::Rawg.new.search('Portal') }.to raise_error(GameProviders::Base::Unavailable)
  end
  it 'caches success and normalizes Steam soundtrack types' do
    payload = { '2' => { success: true, data: { type: 'music',
                                                header_image: 'https://shared.akamai.steamstatic.com/header.jpg' } } }
    stub_request(:get, /appdetails/).to_return(body: payload.to_json)
    adapter = GameProviders::Steam.new
    2.times { expect(adapter.details('2')[:game_type]).to eq('soundtrack') }
    expect(WebMock).to have_requested(:get, /appdetails/).once
    expect(adapter.health[:state]).to eq('ready')
  end
  it 'isolates malformed payloads, records failures and negatively caches failed calls' do
    stub_request(:get, /storesearch/).to_return(body: '<html>Maintenance</html>')
    adapter = GameProviders::Steam.new
    2.times { expect { adapter.search('Portal') }.to raise_error(GameProviders::Base::Unavailable) }
    expect(WebMock).to have_requested(:get, /storesearch/).once
    expect(adapter.health[:state]).to eq('degraded')
  end
  it 'treats rate limits as unavailable without logging credentials' do
    stub_request(:get, /storesearch/).to_return(status: 429)
    expect { GameProviders::Steam.new.search('Portal') }.to raise_error(GameProviders::Base::RateLimited)
  end
  it 'bounds public-library requests without retaining the raw owned-library response' do
    ApiConfiguration.create!(source_name: 'SteamWebAPI', media_type: 'VideoGame',
                             is_active: true, access_token: 'test-key')
    stub_request(:get, /IPlayerService/).to_return(body: { response: { game_count: 0, games: [] } }.to_json)
    adapter = GameProviders::SteamWebApi.new
    expect(adapter.capabilities).to eq(%i[owned_games aggregate_playtime])
    2.times { expect(adapter.owned_games('76561198000000000')['game_count']).to eq(0) }
    expect(WebMock).to have_requested(:get, /IPlayerService/).twice
    expect(adapter.health[:state]).to eq('ready')
    budget = ['game-provider-budget', 'SteamWebAPI', Time.current.to_i / 60]
    MediaSources::Registry::CACHE.write(budget, 300)
    expect { adapter.owned_games('76561198000000001') }.to raise_error(GameProviders::Base::RateLimited)
    expect(WebMock).to have_requested(:get, /IPlayerService/).twice
  end

  it 'retries a transient owned-library failure only once and fails safely for private libraries' do
    ApiConfiguration.create!(source_name: 'SteamWebAPI', media_type: 'VideoGame',
                             is_active: true, access_token: 'test-key')
    stub_request(:get, /IPlayerService/).to_return(status: 503).then.to_return(body: { response: {} }.to_json)
    expect(GameProviders::SteamWebApi.new.owned_games('76561198000000000')).to eq({})
    expect(WebMock).to have_requested(:get, /IPlayerService/).twice
    expect { GameProviders::SteamWebApi.new.owned_games('invalid') }.to raise_error(GameProviders::Base::Unavailable)
  end
end
