# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metadata discovery', type: :request do
  let!(:album) { Album.create!(title: '1989', artist: 'Taylor Swift') }

  it 'renders artist pages and canonical stable URLs with graceful missing images' do
    entity = album.metadata_entities.first
    get metadata_entity_path(entity)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Taylor Swift', '1989', 'Album artist', 'No image available')
    expect(response.body).not_to include('<img src="https://')
    get metadata_entity_path(id: "#{entity.id}-old-name")
    expect(response).to redirect_to(metadata_entity_path(entity))
    expect(response).to have_http_status(:moved_permanently)
  end

  it 'links album artists, actual tracks and their separate contributors' do
    track = album.album_tracks.create!(title: 'Shake It Off', provider_id: 'itunes:1', track_number: 1,
                                       duration_ms: 219_000, credits: [{ 'name' => 'Guest', 'role' => 'Featured artist' }])
    get album_path(album)
    expect(response.body).to include(metadata_entity_path(album.metadata_entities.first), 'Track listing',
                                     'Shake It Off', '3:39', "track-#{track.id}",
                                     metadata_entity_path(track.metadata_entities.first))
  end

  it 'renders writer and artist pages linking only their actual issues' do
    comic = Comic.create!(title: 'Watchmen')
    issue = comic.comic_issues.create!(title: 'Dawn', issue_number: 1, credits: [
                                         { 'name' => 'Alan Moore', 'role' => 'Writer' },
                                         { 'name' => 'Dave Gibbons', 'role' => 'Artist' }
                                       ])
    comic.comic_issues.create!(title: 'Other', issue_number: 2)
    issue.metadata_entities.each do |entity|
      get metadata_entity_path(entity)
      expect(response.body).to include(comic_issue_path(issue), 'Watchmen #1')
      expect(response.body).not_to include('Other')
    end
    get comic_issue_path(issue)
    issue.metadata_entities.each { |entity| expect(response.body).to include(metadata_entity_path(entity)) }
  end

  it 'offers scoped direct entity results and album match context in global search' do
    get search_path(q: 'Taylor Swift')
    expect(response.body).to include('1989', 'Album artist: Taylor Swift',
                                     metadata_entity_path(album.metadata_entities.first))
    get search_path(q: 'Taylor Swift', type: 'movies')
    expect(response.body).not_to include('1989', metadata_entity_path(album.metadata_entities.first))
  end

  it 'uses metadata search on album catalogs and local autocomplete' do
    get albums_path(q: 'Taylor Swift')
    expect(response.body).to include('1989')
    get '/media/autocomplete', params: { q: 'Taylor Swift', type: 'album' }
    expect(response.parsed_body).to include(a_hash_including('title' => '1989', 'is_local' => true))
  end

  it 'paginates unique albums despite several matching role credits' do
    25.times do |index|
      Album.create!(title: "Record #{index}", metadata_credits_data: [
                      { 'name' => 'Matching Person', 'role' => 'Producer' },
                      { 'name' => 'Matching Person', 'role' => 'Composer' }
                    ])
    end
    get albums_path(q: 'Matching Person')
    doc = Nokogiri::HTML(response.body)
    expect(doc.css('.card-2026').size).to eq(24)
    get albums_path(q: 'Matching Person', page: 2)
    expect(Nokogiri::HTML(response.body).css('.card-2026').size).to eq(1)
  end

  it 'supports entity index search and kind filtering with useful empty states' do
    get metadata_entities_path(q: 'Swift', kind: 'artist')
    expect(response.body).to include('Taylor Swift')
    get metadata_entities_path(q: 'Nobody')
    expect(response.body).to include('No matching entities')
  end

  it 'does not expose another member library through the mine filter' do
    user = User.create!(name: 'Reader', email: 'reader@example.com', password: 'password', confirmed_at: Time.current)
    Album.create!(title: 'Other Album', artist: 'Taylor Swift')
    LibraryItem.create!(user: user, item: album, is_collected: true)
    post login_path, params: { session: { email: user.email, password: 'password' } }
    get metadata_entity_path(album.metadata_entities.first, library: 'mine')
    expect(response.body).to include('1989')
    expect(response.body).not_to include('Other Album')
  end
  it 'shares metadata search across private libraries, public collections, shelves, and both admin surfaces' do
    user = User.create!(name: 'Librarian', email: 'librarian@example.com', password: 'password',
                        confirmed_at: Time.current, admin: true)
    LibraryItem.create!(user: user, item: album, is_collected: true)
    post login_path, params: { session: { email: user.email, password: 'password' } }
    get albums_path(library: 'mine', q: 'Taylor Swift')
    expect(response.body).to include('1989')
    get collection_path(user, q: 'Taylor Swift')
    expect(response.body).to include('1989')
    get search_shelves_path(category: 'Album', q: 'Taylor Swift')
    expect(response.parsed_body).to include(a_hash_including('title' => '1989'))
    get admin_search_path(q: 'Taylor Swift')
    expect(response.body).to include('1989')
    get admin_albums_path(search: 'Taylor Swift')
    expect(response.body).to include('1989')
  end

  it 'searches stored narrator and developer metadata in their scoped catalogs' do
    book = Book.create!(title: 'Spoken Book', metadata_credits_data: [{ 'name' => 'Narrator Name', 'role' => 'Narrator' }])
    game = VideoGame.create!(title: 'Game', developer: 'Developer Name')
    get books_path(q: 'Narrator Name')
    expect(response.body).to include(book.title)
    get video_games_path(q: 'Developer Name')
    expect(response.body).to include(game.title)
  end
end
