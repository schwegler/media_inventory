# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Imported metadata confirmation', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { User.create!(name: 'Reader', email: 'import@example.com', password: 'password', confirmed_at: Time.current) }

  def login
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  def token(type, attributes)
    MetadataImport.sign(type, attributes)
  end

  it 'requires authentication and rejects tampered, expired and cross-type selections' do
    post '/media/import_preview', params: { type: 'movie', selection: 'tampered' }
    expect(response).to redirect_to(login_url)
    login
    ['tampered', token('book', title: 'Other')].each do |selection|
      post '/media/import_preview', params: { type: 'movie', selection: selection }
      expect(response).to have_http_status(:unprocessable_content)
    end
    selection = token('movie', title: 'Expired')
    travel_to(31.minutes.from_now) do
      post '/media/import_preview', params: { type: 'movie', selection: selection }
      expect(response).to have_http_status(:unprocessable_content)
    end
    expect(Movie.count).to eq(0)
  end

  it 'loads only the selected TV detail, persists credits/categories and leaves episodes to background reconciliation' do
    login
    stub_request(:get, 'https://api.tvmaze.com/shows/42').to_return(body: {
      summary: '<p>A synopsis</p>', averageRuntime: 45,
      network: { name: 'A network' }, genres: ['Drama'], premiered: '2020-01-01',
      _embedded: { cast: [{ person: { id: 7, name: 'An actor' } }] }
    }.to_json)
    post '/media/import_preview',
         params: { type: 'tv_show', selection: token('tv_show', title: 'A show', api_id: '42', source: 'TVMaze') }
    expect(response).to have_http_status(:ok)
    preview = response.parsed_body
    expect(preview).to include('actors' => 'An actor', 'genre' => 'Drama', 'import_state' => 'ready')
    expect(TvShow.count).to eq(0)
    expect(WebMock).not_to have_requested(:get, 'https://api.tvmaze.com/shows/42/episodes')
    post tv_shows_path, params: { tv_show: { title: 'Injected', network: 'Injected',
                                             import_selection: preview['import_selection'],
                                             rating: '4.5', review: 'My review', in_watchlist: '1' } }
    show = TvShow.last
    expect(show).to have_attributes(title: 'A show', network: 'A network', actors: 'An actor', genre: 'Drama')
    expect(show.metadata_entities.pluck(:name)).to include('An actor', 'Drama', 'A network')
    expect(show.metadata_details).to include('description' => 'A synopsis', 'Runtime' => 45)
    expect(user.library_items.find_by!(item: show)).to have_attributes(review: 'My review', rating: '4.5', in_backlog: true)
    expect(MetadataRefresh.find_by!(item: show).provider_values['network']).to eq('A network')
  end

  it 'preserves structured details and fields for all six media types without legacy callback refetches' do
    login
    {
      'movie' => { director: 'Director', metadata_details: { 'Runtime' => 90 } },
      'tv_show' => { network: 'Network', actors: 'Actor' },
      'album' => { artist: 'Artist', genre: 'Jazz', metadata_details: { 'trackCount' => 10 } },
      'book' => { author: 'Author', publisher: 'Publisher', metadata_details: { 'isbn_13' => ['123'] } },
      'comic' => { writer: 'Writer', artist: 'Artist', publisher: 'Publisher' },
      'video_game' => { developer: 'Developer', platform: 'PC', synopsis: 'Story',
                        metadata_details: { 'genres' => ['Adventure'] } }
    }.each do |type, fields|
      attrs = fields.merge(title: "Imported #{type}", api_id: "wiki_#{type}", release_year: 2020)
      post public_send("#{type.pluralize}_path"),
           params: { type => { import_selection: token(type, attrs), title: 'Ignored' } }
      expect(response).to have_http_status(:redirect)
      item = type.camelize.constantize.last
      fields.each { |field, value| expect(item.public_send(field)).to eq(value) }
      expect(item.release_year).to eq(2020) if item.respond_to?(:release_year)
    end
  end

  it 'does not overwrite any existing shared catalog selection when another member logs it' do
    login
    book = Book.create!(title: 'Curated book', author: 'Correct author', metadata_details: { 'number_of_pages' => 300 })
    selection = token('book', title: 'Stale title', author: 'Wrong', is_local: true, catalog_id: book.id)
    post '/media/import_preview', params: { type: 'book', selection: selection }
    expect(response.parsed_body).to include('author' => 'Correct author', 'import_state' => 'catalog')
    post books_path, params: { book: { import_selection: selection, title: 'Overwrite', review: 'My opinion' } }
    expect(Book.count).to eq(1)
    expect(book.reload.author).to eq('Correct author')
    expect(user.library_items.find_by!(item: book).review).to eq('My opinion')
  end

  it 'honestly offers summary-only imports when detailed lookup is unsupported or unavailable' do
    login
    %w[wiki_4 itunes_4].each do |id|
      stub_request(:get, 'https://itunes.apple.com/lookup?id=4').to_return(status: 503)
      post '/media/import_preview',
           params: { type: 'book', selection: token('book', title: 'Summary', api_id: id, author: 'Author') }
      expect(response.parsed_body).to include('author' => 'Author')
      expect(%w[summary unavailable]).to include(response.parsed_body['import_state'])
    end
  end

  it 'retains manual metadata editing and rejects a forged signed import on save' do
    login
    post books_path, params: { book: { title: 'Manual', author: 'My author', review: 'My review' } }
    expect(Book.last).to have_attributes(title: 'Manual', author: 'My author', api_id: nil)
    post books_path, params: { book: { title: 'Forged', import_selection: 'bad' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Book.where(title: 'Forged')).not_to exist
  end

  it 'keeps conflicting game selections on the existing identity validation path' do
    login
    selected = VideoGame.create!(title: 'Selected game')
    other = VideoGame.create!(title: 'Another game')
    other.update_columns(api_id: 'steam_2')
    selection = token('video_game', title: selected.title, api_id: 'steam_2',
                                    catalog_selection: selected.signed_id(purpose: 'game-catalog-selection'))
    post video_games_path, params: { video_game: { import_selection: selection, title: 'Conflicting import' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Conflicting game identifiers')
    expect(VideoGame.count).to eq(2)
    expect(user.library_items).to be_empty
  end

  it 'renders retained RAWG tags and exact release facts on the saved game' do
    login
    attrs = { title: 'A detailed game', api_id: 'wiki_42', metadata_details: {
      'tags' => ['Exploration'], 'original_release_date' => '2020-02-03', 'official_website' => 'https://example.com/game'
    } }
    post video_games_path, params: { video_game: { import_selection: token('video_game', attrs) } }
    follow_redirect!
    expect(response.body).to include('Exploration', '2020-02-03', 'https://example.com/game')
  end

  it 'accepts large signed descriptions in the request body and keeps tokens stable during polling' do
    login
    fields = { title: 'A long source description', api_id: 'wiki_42', metadata_details: { 'description' => 'x' * 30_000 } }
    first = token('book', fields)
    travel_to(5.seconds.from_now) { expect(token('book', fields)).to eq(first) }
    post '/media/import_preview', params: { type: 'book', selection: first }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['metadata_details']['description'].length).to eq(30_000)
  end

  it 'keeps local game identity and import tokens stable across unchanged search polls' do
    login
    VideoGame.create!(title: 'Stable game')
    allow(MediaSearchService).to receive(:request).and_return(state: 'pending', results: [])
    get '/media/autocomplete', params: { q: 'Stable game', type: 'video_game', async: '1' }
    first = response.parsed_body.first
    travel_to(5.seconds.from_now) do
      get '/media/autocomplete', params: { q: 'Stable game', type: 'video_game', async: '1' }
      expect(response.parsed_body.first['catalog_selection']).to eq(first['catalog_selection'])
      expect(response.parsed_body.first['import_selection']).to eq(first['import_selection'])
    end
  end
end
