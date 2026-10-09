# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportGameArtworkJob do
  let(:game) { VideoGame.create!(title: 'Portal', api_id: 'steam_400') }
  let(:image_url) { 'https://shared.fastly.steamstatic.com/screenshot.png' }

  it 'acquires only returned eligible candidates and keeps existing assets during a later outage' do
    stub_request(:get, %r{store.steampowered.com/api/appdetails}).to_return(body: { '400' => {
      success: true, data: { screenshots: [{ path_full: image_url }] }
    } }.to_json)
    png = File.binread(Rails.root.join('spec/fixtures/files/valid-cover.png'))
    stub_request(:get, image_url).to_return(body: png, headers: { 'Content-Type' => 'image/png' })
    described_class.perform_now(game)
    art = game.game_artworks.first
    expect(art).to have_attributes(kind: 'screenshot', provider: 'Steam', source_url: image_url, library_item_id: nil)
    expect(art.image.blob.content_type).to eq('image/webp')
    expect(game.game_artwork_batch.state).to eq('ready')
    2.times { described_class.perform_now(game) }
    expect(game.game_artworks.count).to eq(1)
    expect(WebMock).to have_requested(:get, image_url).once
    MediaSources::Registry::CACHE.clear
    stub_request(:get, %r{store.steampowered.com/api/appdetails}).to_return(status: 503)
    described_class.perform_now(game)
    expect(game.game_artworks.first.image.blob_id).to eq(art.image.blob_id)
    expect(game.game_artwork_batch.reload.state).to eq('unavailable')
  end
end
