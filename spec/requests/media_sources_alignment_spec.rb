# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Find This Title Links Alignment', type: :request do
  let!(:movie) { Movie.create!(title: 'Dune') }

  it 'renders structured icon, label, and external link layout for all rows' do
    get movie_path(movie)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('class="media-source-icon"')
    expect(response.body).to include('class="media-source-label"')
    expect(response.body).to include('Find this title')
  end

  [Movie, TvShow, Book, Album, Comic, VideoGame].each do |model|
    it "renders an official source for #{model.name} without crashing" do
      source_url = 'https://example.com/catalog/title'
      item = model.create!(title: 'Official source', external_url: source_url)

      get polymorphic_path(item)

      expect(response).to have_http_status(:ok)
      link = Nokogiri::HTML(response.body).at_css('.btn-stream-source')
      expect(link['href']).to eq(source_url)
      expect(link.text.strip).to eq('View Official Source')
      expect(link.at_css('.ui-icon--globe')).to be_present
      expect(link['target']).to eq('_blank')
      expect(link['rel']).to include('noopener')
    end
  end

  it 'renders specialized icon and label for iTunes, Open Library, TVMaze, and Steam links' do
    apple_album = Album.create!(title: 'Apple Album', external_url: 'https://music.apple.com/us/album/123')
    get album_path(apple_album)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('ui-icon--disc')
    expect(response.body).to include('View on Apple Music')

    open_lib_book = Book.create!(title: 'OpenLib Book', external_url: 'https://openlibrary.org/books/OL123M')
    get book_path(open_lib_book)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('ui-icon--book')
    expect(response.body).to include('Borrow on Open Library')

    tvmaze_show = TvShow.create!(title: 'TVMaze Show', external_url: 'https://www.tvmaze.com/shows/123')
    get tv_show_path(tvmaze_show)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('ui-icon--tv')
    expect(response.body).to include('View on TVmaze')

    steam_game = VideoGame.create!(title: 'Steam Game', external_url: 'https://store.steampowered.com/app/123')
    get video_game_path(steam_game)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('ui-icon--gamepad')
    expect(response.body).to include('View on Steam')
  end
end
