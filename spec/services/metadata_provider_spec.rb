# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MetadataProvider do
  def catalog_item(klass, id, **attributes)
    item = klass.create!(title: 'A personal title')
    item.update_columns(api_id: id, **attributes)
    item
  end

  def json_response(url, payload, **query)
    stub_request(:get, url).with(query: query).to_return(body: payload.to_json)
  end

  it 'refreshes TMDB television seasons through existing stored IDs' do
    item = catalog_item(TvShow, 'tmdb_12')
    ApiConfiguration.create!(source_name: 'TMDB', is_active: true, access_token: 'test')
    json_response('https://api.themoviedb.org/3/tv/12', { seasons: [{ season_number: 1 }] }, api_key: 'test')
    json_response('https://api.themoviedb.org/3/tv/12/season/1',
                  { episodes: [{ name: 'Pilot', season_number: 1, episode_number: 1, air_date: '2026-10-01' }] },
                  api_key: 'test')
    fields, rows = described_class.new(item).call
    expect(fields).to include(:network)
    expect(rows.first).to include('season' => 1, 'number' => 1, 'name' => 'Pilot')
  end

  it 'refreshes TMDB movie artwork without searching for a different title' do
    item = catalog_item(Movie, '42')
    ApiConfiguration.create!(source_name: 'TMDB', is_active: true, access_token: 'test')
    json_response('https://api.themoviedb.org/3/movie/42', { poster_path: '/new.jpg', release_date: '2026-01-01' },
                  api_key: 'test', append_to_response: 'credits')
    fields, = described_class.new(item).call
    expect(fields).to include(release_year: 2026, thumbnail_url: 'https://image.tmdb.org/t/p/w500/new.jpg')
  end

  it 'uses iTunes lookup for books and albums with numeric IDs' do
    [Book, Album].each do |klass|
      item = catalog_item(klass, '42')
      json_response('https://itunes.apple.com/lookup',
                    { results: [{ artistName: 'Creator', artworkUrl100: 'https://images.example/100x100bb.jpg' }] },
                    id: '42')
      fields, = described_class.new(item).call
      expect(fields[:thumbnail_url]).to start_with('https://images.example/')
      expect(fields[klass == Book ? :author : :artist]).to eq('Creator')
    end
  end

  it 'refreshes namespaced iTunes identifiers returned by catalog search' do
    [Book, Album, Movie].each do |klass|
      item = catalog_item(klass, 'itunes_42')
      json_response('https://itunes.apple.com/lookup', { results: [{ artistName: 'Creator' }] }, id: '42')
      fields, = described_class.new(item).call
      expect(fields.values).to include('Creator')
    end
  end

  it 'respects MusicBrainz release-group provenance' do
    id = 'abcdefab-1234-1234-1234-abcdef123456'
    item = catalog_item(Album, id, external_url: "https://musicbrainz.org/release-group/#{id}")
    json_response("https://musicbrainz.org/ws/2/release-group/#{id}",
                  { 'artist-credit' => [{ name: 'Creator' }], 'first-release-date' => '2026-01-01' },
                  fmt: 'json', inc: 'artist-credits+genres')
    fields, = described_class.new(item).call
    expect(fields[:thumbnail_url]).to eq("https://coverartarchive.org/release-group/#{id}/front-500")
    expect(fields[:artist]).to eq('Creator')
  end

  it 'refreshes Steam and RAWG through fixed endpoints' do
    steam = catalog_item(VideoGame, 'steam_42')
    steam_data = { developers: ['Creator'], header_image: 'https://shared.fastly.steamstatic.com/real.jpg' }
    json_response('https://store.steampowered.com/api/appdetails',
                  { '42' => { success: true, data: steam_data } }, appids: '42')
    fields, = described_class.new(steam).call
    expect(fields[:developer]).to eq('Creator')
    expect(fields[:thumbnail_url]).to eq('https://shared.fastly.steamstatic.com/real.jpg')
    rawg = catalog_item(VideoGame, 'rawg_12')
    ApiConfiguration.create!(source_name: 'RAWG', is_active: true, access_token: 'test')
    json_response('https://api.rawg.io/api/games/12', { background_image: 'https://images.example/game.jpg' }, key: 'test')
    fields, = described_class.new(rawg).call
    expect(fields[:thumbnail_url]).to eq('https://images.example/game.jpg')
  end

  it 'fills comic credits from the first issue without downloading the issue list during search' do
    item = catalog_item(Comic, '42')
    ApiConfiguration.create!(source_name: 'ComicVine', media_type: 'Comic', is_active: true, access_token: 'test')
    json_response('https://comicvine.gamespot.com/api/volume/4050-42/',
                  { status_code: 1, results: { publisher: { name: 'Marvel' }, first_issue: { id: 123 } } },
                  api_key: 'test', format: 'json')
    json_response('https://comicvine.gamespot.com/api/issue/4000-123/',
                  { status_code: 1, results: { person_credits: [
                    { name: 'Writer', role: 'writer' }, { name: 'Artist', role: 'penciler, inker' },
                    { name: 'Editor', role: 'editor' }
                  ] } }, api_key: 'test', format: 'json')
    fields, rows = described_class.new(item, include_children: false).call
    expect(fields).to include(writer: 'Writer', artist: 'Artist', publisher: 'Marvel')
    expect(rows).to be_empty
    expect(WebMock).not_to have_requested(:get, 'https://comicvine.gamespot.com/api/issues/')
  end

  it 'retains comic metadata when the optional creator request is unavailable' do
    item = catalog_item(Comic, '42')
    ApiConfiguration.create!(source_name: 'ComicVine', is_active: true, access_token: 'test')
    json_response('https://comicvine.gamespot.com/api/volume/4050-42/',
                  { status_code: 1, results: { publisher: { name: 'Marvel' }, first_issue: { id: 123 } } },
                  api_key: 'test', format: 'json')
    stub_request(:get, %r{comicvine.*issue/4000-123}).to_return(status: 429)
    adapter = described_class.new(item, include_children: false)
    fields, = adapter.call
    expect(fields[:publisher]).to eq('Marvel')
    expect(adapter.partial).to be true
  end

  it 'maps movie directors without including other crew roles' do
    item = catalog_item(Movie, '42')
    ApiConfiguration.create!(source_name: 'TMDB', is_active: true, access_token: 'test')
    json_response('https://api.themoviedb.org/3/movie/42',
                  { credits: { crew: [{ name: 'Director A', job: 'Director' },
                                      { name: 'Director B', job: 'Director' }, { name: 'Writer', job: 'Writer' }] } },
                  api_key: 'test', append_to_response: 'credits')
    fields, = described_class.new(item).call
    expect(fields[:director]).to eq('Director A, Director B')
  end

  it 'rejects unsafe IDs and disabled sources without any external request' do
    item = catalog_item(TvShow, '../42')
    expect { described_class.new(item).call }.to raise_error(MetadataProvider::Unsupported)
    item.update_columns(api_id: '42')
    ApiConfiguration.create!(source_name: 'tvmaze', media_type: 'TvShow', is_active: false)
    expect { described_class.new(item).call }.to raise_error(MetadataProvider::Unavailable)
    expect(WebMock).not_to have_requested(:get, /tvmaze/)
  end
end
