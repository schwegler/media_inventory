# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaSearchService do
  before do
    MediaSources::Registry::CACHE.clear
    stub_request(:get, /en.wikipedia.org/).to_return(body: { query: { pages: {} } }.to_json)
  end

  it 'uses Steam supplied artwork without guessing library paths or per-result requests' do
    stub_request(:get, %r{store.steampowered.com/api/storesearch}).to_return(body: {
      items: [{ id: 620, name: 'Portal 2', tiny_image: 'https://shared.fastly.steamstatic.com/real.jpg' }]
    }.to_json)
    result = described_class.call('Portal', 'video_game').first
    expect(result).to include(api_id: 'steam_620', source: 'Steam', thumbnail_url: 'https://shared.fastly.steamstatic.com/real.jpg')
    expect(WebMock).not_to have_requested(:get, /appdetails/)
    described_class.call('Portal', 'video_game')
    expect(WebMock).to have_requested(:get, /storesearch/).once
  end

  it 'uses no-key book and comic sources and isolates failed providers' do
    stub_request(:get, %r{openlibrary.org/search}).to_return(body: { docs: [
      { key: '/works/OL1W', title: 'Watchmen', cover_i: 123, author_name: ['Alan Moore'] }
    ] }.to_json)
    result = described_class.call('Watchmen', 'comic').first
    expect(result).to include(title: 'Watchmen', writer: 'Alan Moore', source: 'OpenLibrary')
    expect(result[:thumbnail_url]).to eq('https://covers.openlibrary.org/b/id/123-M.jpg')
  end

  it 'honors disabled sources independently by media category' do
    ApiConfiguration.create!(source_name: 'Steam', media_type: 'VideoGame', is_active: false)
    expect(described_class.call('Portal', 'video_game')).to eq([])
    expect(WebMock).not_to have_requested(:get, /store.steampowered.com/)
  end

  it 'falls back after an upstream error' do
    stub_request(:get, /storesearch/).to_return(status: 503)
    stub_request(:get, /en.wikipedia.org/).to_return(body: { query: { pages: {
      '1' => { title: 'Portal (video game)', pageid: 1, thumbnail: { source: 'https://upload.wikimedia.org/cover.jpg' } }
    } } }.to_json)
    expect(described_class.call('Portal', 'video_game').first[:source]).to eq('Wikipedia')
  end
  it 'adds Internet Archive artwork for each supported media category' do
    stub_request(:get, %r{archive.org/advancedsearch}).to_return(body: { response: { docs: [
      { identifier: 'public-work', title: 'Public work', creator: ['An Author'], date: '2001-01-01' }
    ] } }.to_json)
    %w[movie tv_show album comic book video_game].each do |type|
      result = described_class.call('Public work', type).find { |r| r[:source] == 'InternetArchive' }
      expect(result).to include(thumbnail_url: 'https://archive.org/services/img/public-work', release_year: '2001')
    end
  end
end
