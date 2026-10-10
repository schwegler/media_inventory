# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'Independent artwork sources' do
  let(:png) { File.binread(Rails.root.join('spec/fixtures/files/valid-cover.png')) }
  before do
    MediaSources::Registry::CACHE.clear
    stub_request(:get, %r{shared.fastly.steamstatic.com/.*/library_600x900_2x.jpg}).to_return(status: 404)
  end

  it 'tries Steam portrait artwork before the horizontal header' do
    original = { api_id: 'steam_400', source: 'Steam', thumbnail_url: 'https://shared.akamai.steamstatic.com/header.jpg' }
    candidates = GameArtworkResolver.candidates(original)
    expect(candidates.map { |candidate| candidate[:artwork_type] }).to eq(%w[portrait_cover cover])
    expect(candidates.first[:url]).to include('/400/library_600x900_2x.jpg')
    stub_request(:get, candidates.first[:url]).to_return(body: png, headers: { 'Content-Type' => 'image/png' })
    expect(GameSearchArtwork.call([original]).first[:artwork_status]).to eq('ready')
    expect(WebMock).not_to have_requested(:get, original[:thumbnail_url])
  end
  it 'retains Steam metadata while selecting a verified SteamGridDB portrait through the Steam ID' do
    ApiConfiguration.create!(source_name: 'SteamGridDB', media_type: 'VideoGame', is_active: true,
                             access_token: 'secret-test-key', options: { allow_image_storage: true }.to_json)
    payload = { success: true, data: [{ id: 12, width: 600, height: 900, score: 10,
                                        url: 'https://cdn2.steamgriddb.com/grid/12.png', author: { name: 'Artist' } }] }
    stub_request(:get, %r{www.steamgriddb.com/api/v2/grids/steam/1794680})
      .with(headers: { 'Authorization' => 'Bearer secret-test-key' }).to_return(body: payload.to_json)
    stub_request(:get, 'https://cdn2.steamgriddb.com/grid/12.png').to_return(body: png,
                                                                             headers: { 'Content-Type' => 'image/png' })
    original = { title: 'Vampire Survivors', api_id: 'steam_1794680', source: 'Steam', developer: 'poncle',
                 thumbnail_url: 'https://shared.akamai.steamstatic.com/header.jpg' }
    result = GameSearchArtwork.call([original]).first
    expect(result).to include(source: 'Steam', api_id: 'steam_1794680', developer: 'poncle',
                              artwork_source: 'SteamGridDB', artwork_match: 'steam_app_id', artwork_status: 'ready')
    expect(result[:thumbnail_url]).to start_with('/rails/active_storage/blobs/proxy/')
    expect(MediaArtworkSource.last.provenance).to include('author' => 'Artist')
  end
  it 'falls back to the metadata provider when an alternate provider is unavailable' do
    original = { title: 'Portal', api_id: 'steam_400', source: 'Steam', thumbnail_url: 'https://shared.akamai.steamstatic.com/header.jpg' }
    stub_request(:get, original[:thumbnail_url]).to_return(body: png, headers: { 'Content-Type' => 'image/png' })
    expect(GameSearchArtwork.call([original]).first[:artwork_source]).to eq('Steam')
  end
  it 'does not enable storage for a key alone or borrow covers on title similarity' do
    ApiConfiguration.create!(source_name: 'SteamGridDB', media_type: 'VideoGame', is_active: true, access_token: 'test')
    expect(GameProviders::SteamGridDb.new.enabled?).to be(false)
    game = { title: 'Prey', game_type: 'game', release_year: 2006, developer: 'Human Head' }
    remake = { title: 'Prey', game_type: 'game', release_year: 2017, developer: 'Arkane', thumbnail_url: 'https://media.rawg.io/prey.jpg' }
    expect(GameArtworkResolver.candidates(game, results: [remake])).to be_empty
  end
  it 'uses another provider image after a validated match when the first image is broken' do
    left = { title: 'Portal', game_type: 'game', release_year: 2007, developer: 'Valve', source: 'Steam',
             api_id: 'steam_400', thumbnail_url: 'https://shared.akamai.steamstatic.com/broken.jpg' }
    right = left.merge(source: 'RAWG', api_id: 'rawg_135', thumbnail_url: 'https://media.rawg.io/portal.jpg')
    stub_request(:get, left[:thumbnail_url]).to_return(status: 404)
    stub_request(:get, right[:thumbnail_url]).to_return(body: png, headers: { 'Content-Type' => 'image/png' })
    expect(GameSearchArtwork.call([left,
                                   right]).first).to include(api_id: 'steam_400', source: 'Steam', artwork_source: 'RAWG')
  end
end
