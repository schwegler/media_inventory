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

  it 'renders official source globe fallback icon for generic external URLs without 500 KeyError' do
    book = Book.create!(title: 'Goodreads Book', external_url: 'https://www.goodreads.com/book/show/123')
    get book_path(book)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('ui-icon--globe')
    expect(response.body).to include('View Official Source')

    comic = Comic.create!(title: 'ComicVine Comic', external_url: 'https://comicvine.gamespot.com/comic/4000-123/')
    get comic_path(comic)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('ui-icon--globe')

    movie_tmdb = Movie.create!(title: 'TMDB Movie', external_url: 'https://www.themoviedb.org/movie/123')
    get movie_path(movie_tmdb)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('ui-icon--globe')
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
