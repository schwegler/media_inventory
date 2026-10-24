# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public discovery and sign-in continuation', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) do
    User.create!(name: 'Fixture Listener', email: 'discovery@example.com', password: 'password', confirmed_at: Time.current)
  end
  let(:selection) do
    MetadataImport.sign('album', title: 'Synthetic album', artist: 'Charli xcx', api_id: 'itunes_777', source: 'itunes')
  end

  def select_album
    post discovery_selection_path, params: { type: 'album', selection: selection, q: 'Charli xcx' }
  end

  def login
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  it 'offers public search and explains the six formats and catalog boundary' do
    get root_path
    expect(response.body).to include('Track games, music, books, movies, TV and comics', 'home-discovery-query',
                                     'Coverage varies', 'Search without an account')
    expect(response.body).not_to include('Explore public shelves')
    get search_path(q: 'Madonna')
    expect(response.body).to include('In Trove', 'Available to import', 'Search music (albums)', 'Find more matches')
    expect(response.body).not_to include('data-controller="discovery-search"')
    expect(WebMock).not_to have_requested(:get, /itunes.apple.com/)
  end

  ['Madonna', 'Buckethead', 'Charli xcx'].each do |artist|
    it "preserves #{artist} and exposes bounded external album discovery beside local results" do
      Album.create!(title: "Local #{artist} fixture", artist: artist)
      get search_path(q: artist, type: 'albums')
      page = Nokogiri::HTML(response.body)
      expect(page.at_css('[data-controller="discovery-search"]')['data-discovery-search-query-value']).to eq(artist)
      expect(response.body).to include("Local #{artist} fixture", 'In Trove', 'Available to import',
                                       'not complete catalogs or discographies', 'Refine your search')
      expect(Album.count).to eq(1)
      expect(LibraryItem.count).to eq(0)
    end
  end

  it 'retains selection through failed login, signup navigation, and successful login without importing' do
    select_album
    expect(response).to redirect_to(login_path)
    get login_path
    expect(response.body).to include('Your selection is saved', 'Charli xcx')
    post login_path, params: { session: { email: user.email, password: 'wrong' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Your selection is saved')
    get signup_path
    expect(response.body).to include('Your selection is saved')
    login
    expect(response).to redirect_to(resume_discovery_path)
    get resume_discovery_path
    expect(response).to redirect_to(new_album_path(discovery: '1'))
    follow_redirect!
    expect(response.body).to include('data-thumbnail-fetcher-selection-value', 'Synthetic album',
                                     'Back to discovery results')
    expect(Album.count).to eq(0)
    expect(LibraryItem.count).to eq(0)
  end

  it 'retains the selected item through signup but still requires explicit save' do
    select_album
    post users_path, params: { user: { name: 'New synthetic listener', email: 'new-discovery@example.com',
                                       password: 'password', password_confirmation: 'password' } }
    expect(response).to redirect_to(resume_discovery_path)
    expect(Album.count).to eq(0)
    expect(LibraryItem.count).to eq(0)
  end

  it 'rejects tampering and cross-type selections without storing an intent or importing' do
    ['tampered', MetadataImport.sign('book', title: 'Not an album')].each do |token|
      post discovery_selection_path, params: { type: 'album', selection: token, q: 'Buckethead', return_to: 'https://evil.example/' }
      expect(response).to redirect_to(search_path(q: 'Buckethead'))
    end
    login
    expect(response).to redirect_to(user)
    expect(Album.count).to eq(0)
  end

  it 'returns an expired selection to its original search and clears continuation on logout' do
    select_album
    travel 31.minutes
    login
    get resume_discovery_path
    follow_redirect!
    expect(response).to redirect_to(search_path(q: 'Charli xcx', type: 'albums'))
    delete logout_path
    login
    expect(response).to redirect_to(user)
  end

  it 'adds only on explicit save, reuses the signed identity on repeated submits, and clears intent' do
    select_album
    login
    2.times do
      post albums_path, params: { discovery: '1', album: { import_selection: selection, is_collected: '1' } }
      expect(response).to redirect_to(Album.last)
    end
    expect(Album.where(api_id: 'itunes_777').count).to eq(1)
    expect(user.library_items.where(item: Album.last).count).to eq(1)
    get login_path
    expect(response.body).not_to include('Your selection is saved')
  end

  it 'does not overwrite personal tracking when another discovery confirmation already added the title' do
    album = Album.create!(title: 'Synthetic album', api_id: 'itunes_777')
    library = user.library_items.create!(item: album, is_collected: true, consumed: true, rating: '4.5',
                                         is_public: false, review: 'Keep my review')
    select_album
    login
    post albums_path,
         params: { discovery: '1', album: { import_selection: selection, review: '', rating: '', consumed: '0' } }
    expect(response).to redirect_to(album)
    expect(flash[:notice]).to eq('This title is already in your library.')
    expect(library.reload).to have_attributes(consumed: true, rating: '4.5', review: 'Keep my review', is_public: false)
    expect(user.library_items.count).to eq(1)
  end

  it 'keeps signed URL-only identities distinct even when the titles match' do
    login
    2.times do |i|
      token = MetadataImport.sign('book', title: 'Same synthetic title', external_url: "https://openlibrary.org/works/#{i}")
      post books_path, params: { book: { import_selection: token, is_collected: '1' } }
      expect(response).to have_http_status(:redirect)
    end
    expect(Book.where(title: 'Same synthetic title').count).to eq(2)
    expect(user.library_items.where(item_type: 'Book').count).to eq(2)
  end

  it 'labels only the signed-in member’s library and prevents caching personalized search HTML' do
    album = Album.create!(title: 'Synthetic membership album', artist: 'Buckethead')
    user.library_items.create!(item: album, is_collected: true, is_public: false, review: 'Private opinion')
    login
    get search_path(q: 'Buckethead', type: 'albums')
    expect(response.headers['Cache-Control']).to include('private', 'no-store')
    expect(response.body).to include('In Trove · In your library', 'turbo-cache-control')
    expect(response.body).not_to include('Private opinion')
    delete logout_path
    get search_path(q: 'Buckethead', type: 'albums')
    expect(response.body).not_to include('In your library', 'Private opinion')
  end

  it 'does not acquire an import identity or create catalog records before authentication' do
    post albums_path, params: { album: { import_selection: selection } }
    expect(response).to redirect_to(login_url)
    expect(ShelfCatalogIdentity.count).to eq(0)
    expect(Album.count).to eq(0)
  end

  it 'shows only real populated shelves from confirmed members who published a share preview' do
    user.update!(username: 'synthetic_listener')
    album = Album.create!(title: 'A real fixture pick')
    user.favorite_shelves.create!(category: 'Album', picks: [{ 'type' => 'Album', 'id' => album.id }])
    get root_path
    expect(response.body).not_to include('Explore public shelves')
    user.shelf_previews.attach(io: File.open(Rails.root.join('spec/fixtures/files/valid-cover.png')),
                               filename: 'synthetic-preview.png', content_type: 'image/png')
    get root_path
    expect(response.body).to include('Explore public shelves', 'A real fixture pick',
                                     shelf_path(user.username, category: 'Album'))
    expect(response.body).not_to include('Private opinion')
    user.update!(confirmed_at: nil)
    get root_path
    expect(response.body).not_to include('Explore public shelves')
  end

  it 'keeps the existing array autocomplete API while exposing provider outcomes in discovery' do
    allow(MediaSearchService).to receive(:request).and_return(state: 'ready', results: [])
    allow(MediaSearchService).to receive(:source_states).and_return([{ source: 'itunes', state: 'unavailable' }])
    get '/media/autocomplete', params: { q: 'Buckethead', type: 'album', async: '1', discovery: '1' }
    expect(response.parsed_body).to include('results' => [],
                                            'sources' => [{
                                              'source' => 'itunes', 'state' => 'unavailable'
                                            }])
    get '/media/autocomplete', params: { q: 'Buckethead', type: 'album', async: '1' }
    expect(response.parsed_body).to eq([])
  end
end
