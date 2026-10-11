# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Personal media libraries', type: :request do
  let(:user) { User.create!(name: 'Reader', email: 'shelves@example.com', password: 'password123') }
  let(:other) { User.create!(name: 'Other', email: 'other-shelves@example.com', password: 'password123') }

  def sign_in
    post login_path, params: { session: { email: user.email, password: 'password123' } }
  end

  [Movie, TvShow, Book, Album, Comic].each do |klass|
    it "provides a private, searchable #{klass.name} collection with personal sorting and ownership shelves" do
      first = klass.create!(title: 'My earlier title')
      recent = klass.create!(title: 'My recent title')
      foreign = klass.create!(title: 'Foreign private title')
      LibraryItem.create!(user: user, item: first, in_backlog: true, owned_physically: true, rating: '5',
                          created_at: 2.days.ago)
      LibraryItem.create!(user: user, item: recent, rating: '3', created_at: 1.day.ago)
      LibraryItem.create!(user: other, item: foreign, in_backlog: true)
      path = polymorphic_path(klass)
      get path, params: { library: 'mine' }
      expect(response).to redirect_to(login_path)
      sign_in
      get path, params: { library: 'mine' }
      expect(response).to have_http_status(:ok)
      expect(response.headers['Cache-Control']).to include('private', 'no-store')
      expect(response.body).to include('My library', 'Library shelves', 'My earlier title', 'My recent title')
      expect(response.body).not_to include('Foreign private title')
      expect(response.body.index('My recent title')).to be < response.body.index('My earlier title')
      get path, params: { library: 'mine', status: 'physical', layout: 'list' }
      expect(response.body).to include('My earlier title', 'collection-list')
      expect(response.body).not_to include('My recent title')
      get path, params: { library: 'mine', sort: 'rating' }
      expect(response.body.index('My earlier title')).to be < response.body.index('My recent title')
      get path, params: { library: 'mine', q: 'recent' }
      expect(response.body).to include('My recent title')
      expect(response.body).not_to include('My earlier title')
      get path
      expect(response.body).to include('Foreign private title')
      expect(response.body).not_to include('Library shelves')
    end
  end

  it 'combines bespoke metadata with the selected shelf and preserves filters in shelf links' do
    sign_in
    book = Book.create!(title: 'A reading queue', author: 'Ursula Le Guin', release_year: 1969)
    LibraryItem.create!(user: user, item: book, in_backlog: true)
    get books_path, params: { library: 'mine', author: 'le guin', year: '1969', status: 'backlog', layout: 'list' }
    expect(response.body).to include('A reading queue', 'More filters · active')
    doc = Nokogiri::HTML(response.body)
    read_shelf = doc.at_css('.library-shelves a[aria-current="page"]')
    expect(read_shelf.text).to eq('To read')
    expect(read_shelf['href']).to include('author=le+guin', 'year=1969', 'layout=list')
    get books_path, params: { library: 'mine', author: 'different author' }
    expect(response.body).to include('No titles on this shelf')
    expect(response.body).not_to include('A reading queue')
  end

  it 'shows progress from the active reread rather than lifetime completion, and scopes watching to the owner' do
    comic = Comic.create!(title: 'A reread')
    issue = comic.comic_issues.create!(title: 'Issue one', issue_number: 1)
    comic.comic_issues.create!(title: 'Issue two', issue_number: 2)
    library = LibraryItem.create!(user: user, item: comic, consumed: true)
    library.consumption_passes.create!(number: 1, status: 'completed')
    pass = library.consumption_passes.create!(number: 2, status: 'active')
    pass.entries.create!(item: issue, consumed_at: Time.current)
    sign_in
    get comics_path, params: { library: 'mine', status: 'progress' }
    expect(response.body).to include('1 / 2 issues read', 'A reread')
    pass.update!(status: 'dismissed')
    get comics_path, params: { library: 'mine', status: 'progress' }
    expect(response.body).to include('No titles on this shelf')
  end
  it 'filters personal formats without matching another owners edition' do
    album = Album.create!(title: 'A shared record', artist: '100% Band')
    other_album = Album.create!(title: 'Different record', artist: '1000 Band')
    LibraryItem.create!(user: user, item: album, owned_physically: true, owned_physically_format: 'Vinyl')
    LibraryItem.create!(user: user, item: other_album, owned_digitally: true, owned_digitally_format: 'FLAC')
    LibraryItem.create!(user: other, item: album, owned_physically_format: 'Secret pressing')
    sign_in
    get albums_path, params: { library: 'mine', format: 'Vinyl' }
    expect(response.body).to include('A shared record')
    expect(response.body).not_to include('Different record', 'Secret pressing')
    get albums_path, params: { library: 'mine', artist: '100%' }
    expect(response.body).to include('A shared record')
    expect(response.body).not_to include('Different record')
  end
end
