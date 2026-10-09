# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaSearchService do
  before do
    MediaSources::Registry::CACHE.clear
    stub_request(:get, /en.wikipedia.org/).to_return(body: { query: { pages: {} } }.to_json)
  end

  it 'uses Steam supplied artwork and enriches details once before caching' do
    stub_request(:get, %r{store.steampowered.com/api/storesearch}).to_return(body: {
      items: [{ id: 620, name: 'Portal 2', tiny_image: 'https://shared.fastly.steamstatic.com/real.jpg' }]
    }.to_json)
    stub_request(:get, /appdetails/).to_return(body: { '620' => { success: true, data: {
      developers: ['Valve'], publishers: ['Valve'], platforms: { windows: true },
      release_date: { date: 'Apr 18, 2011' }
    } } }.to_json)
    result = described_class.call('Portal', 'video_game').first
    expect(result).to include(api_id: 'steam_620', source: 'Steam', thumbnail_url: 'https://shared.fastly.steamstatic.com/real.jpg')
    expect(result).to include(developer: 'Valve', publisher: 'Valve', platform: 'windows', release_year: '2011')
    described_class.call('Portal', 'video_game')
    expect(WebMock).to have_requested(:get, /storesearch/).once
    expect(WebMock).to have_requested(:get, /appdetails/).once
  end

  it 'retains a search result when its detail request fails' do
    stub_request(:get, /storesearch/).to_return(body: { items: [
      { id: 620, name: 'Portal 2', tiny_image: 'https://shared.fastly.steamstatic.com/real.jpg' }
    ] }.to_json)
    stub_request(:get, /appdetails/).to_return(status: 503)
    expect(described_class.call('Portal', 'video_game').first).to include(title: 'Portal 2', api_id: 'steam_620')
  end

  it 'combines duplicate releases while preserving the selected provider identity' do
    ApiConfiguration.create!(source_name: 'TMDB', media_type: 'Movie', is_active: true, access_token: 'test')
    stub_request(:get, /api.themoviedb.org.*search/).to_return(body: { results: [
      { id: 42, title: 'A Movie', release_date: '2001-01-01', poster_path: '/poster.jpg' }
    ] }.to_json)
    stub_request(:get, %r{api.themoviedb.org/3/movie/42}).to_return(status: 503)
    stub_request(:get, /itunes.apple.com.*search/).to_return(body: { results: [
      { trackId: 99, trackName: 'A Movie', releaseDate: '2001-01-01', artistName: 'Director',
        artworkUrl100: 'https://images.example/100x100bb.jpg', trackViewUrl: 'https://itunes.apple.com/movie/99' }
    ] }.to_json)
    results = described_class.call('A Movie', 'movie')
    expect(results.size).to eq(1)
    expect(results.first).to include(director: 'Director', api_id: '42', source: 'TMDB',
                                     external_url: 'https://www.themoviedb.org/movie/42')
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
