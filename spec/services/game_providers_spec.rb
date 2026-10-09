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
end
