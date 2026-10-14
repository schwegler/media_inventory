# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Categories', type: :request do
  let!(:movie1) do
    Movie.create!(
      title: 'Inception',
      release_year: 2010,
      director: 'Christopher Nolan',
      writer: 'Christopher Nolan',
      actors: 'Leonardo DiCaprio, Joseph Gordon-Levitt, Elliot Page',
      genre: 'Action, Sci-Fi'
    )
  end

  let!(:movie2) do
    Movie.create!(
      title: 'Interstellar',
      release_year: 2014,
      director: 'Christopher Nolan',
      writer: 'Jonathan Nolan, Christopher Nolan',
      actors: 'Matthew McConaughey, Anne Hathaway, Jessica Chastain',
      genre: 'Adventure, Drama, Sci-Fi'
    )
  end

  let!(:tv_show1) do
    TvShow.create!(
      title: 'Westworld',
      network: 'HBO',
      release_year: 2016,
      director: 'Jonathan Nolan',
      writer: 'Jonathan Nolan, Lisa Joy',
      actors: 'Evan Rachel Wood, Thandiwe Newton, Jeffrey Wright',
      genre: 'Sci-Fi, Western'
    )
  end

  describe 'GET /categories' do
    it 'returns http success and displays category sections' do
      get categories_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Categories')
      expect(response.body).to include('Genres')
      expect(response.body).to include('Directors')
      expect(response.body).to include('Actors')
      expect(response.body).to include('Writers')
      expect(response.body).to include('Christopher Nolan')
      expect(response.body).to include('Sci-Fi')
    end
  end

  describe 'GET /categories/:category_type' do
    it 'lists directors' do
      get category_type_path(category_type: 'directors')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Directors')
      expect(response.body).to include('Christopher Nolan')
      expect(response.body).to include('Jonathan Nolan')
    end

    it 'lists actors' do
      get category_type_path(category_type: 'actors')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Actors')
      expect(response.body).to include('Leonardo DiCaprio')
      expect(response.body).to include('Evan Rachel Wood')
    end

    it 'lists genres' do
      get category_type_path(category_type: 'genres')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Genres')
      expect(response.body).to include('Sci-Fi')
      expect(response.body).to include('Action')
    end

    it 'lists writers' do
      get category_type_path(category_type: 'writers')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Writers')
      expect(response.body).to include('Jonathan Nolan')
      expect(response.body).to include('Lisa Joy')
    end

    it 'filters categories with search query' do
      get category_type_path(category_type: 'actors', q: 'DiCaprio')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Leonardo DiCaprio')
      expect(response.body).not_to include('Evan Rachel Wood')
    end

    it 'redirects invalid category type to /categories' do
      get category_type_path(category_type: 'producers')
      expect(response).to redirect_to(categories_path)
    end
  end

  describe 'GET /categories/:category_type/*name' do
    it 'renders the category page for a director' do
      get category_item_path(category_type: 'directors', name: 'Christopher Nolan')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Christopher Nolan')
      expect(response.body).to include('Inception')
      expect(response.body).to include('Interstellar')
      expect(response.body).not_to include('Westworld')
    end

    it 'renders the category page for a genre with mixed media' do
      get category_item_path(category_type: 'genres', name: 'Sci-Fi')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Sci-Fi')
      expect(response.body).to include('Inception')
      expect(response.body).to include('Interstellar')
      expect(response.body).to include('Westworld')
    end

    it 'filters by media type' do
      get category_item_path(category_type: 'genres', name: 'Sci-Fi', type: 'tv_shows')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Westworld')
      expect(response.body).not_to include('Inception')
    end

    it 'renders the category page for an actor' do
      get category_item_path(category_type: 'actors', name: 'Leonardo DiCaprio')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Leonardo DiCaprio')
      expect(response.body).to include('Inception')
      expect(response.body).not_to include('Westworld')
    end
  end

  describe 'Category links on media detail pages' do
    it 'renders clickable category links on movie show page' do
      get movie_path(movie1)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(category_item_path(category_type: 'directors', name: 'Christopher Nolan'))
      expect(response.body).to include(category_item_path(category_type: 'writers', name: 'Christopher Nolan'))
      expect(response.body).to include(category_item_path(category_type: 'actors', name: 'Leonardo DiCaprio'))
      expect(response.body).to include(category_item_path(category_type: 'genres', name: 'Sci-Fi'))
    end

    it 'renders clickable category links on tv show show page' do
      get tv_show_path(tv_show1)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(category_item_path(category_type: 'directors', name: 'Jonathan Nolan'))
      expect(response.body).to include(category_item_path(category_type: 'writers', name: 'Lisa Joy'))
      expect(response.body).to include(category_item_path(category_type: 'actors', name: 'Evan Rachel Wood'))
      expect(response.body).to include(category_item_path(category_type: 'genres', name: 'Western'))
    end
  end
  describe 'shared writers and authors category detail views' do
    let!(:book) { Book.create!(title: 'Stardust', author: 'Neil Gaiman', release_year: 1999) }
    let!(:comic) { Comic.create!(title: 'The Sandman', writer: 'Neil Gaiman') }

    it 'renders books and comics on authors category page with Books tab' do
      get category_item_path(category_type: 'authors', name: 'Neil Gaiman')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Stardust')
      expect(response.body).to include('The Sandman')
      expect(response.body).to include('Books (1)')
      expect(response.body).to include('Comics (1)')
    end

    it 'filters books on authors category page by books media type' do
      get category_item_path(category_type: 'authors', name: 'Neil Gaiman', type: 'books')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Stardust')
      expect(response.body).not_to include('The Sandman')
    end
  end

  describe 'video game platform categories' do
    let!(:game) { VideoGame.create!(title: 'Portal', platform: 'PC, Nintendo Switch') }

    it 'includes platforms in the category hub and navigation' do
      get categories_path
      expect(response.body).to include(category_type_path(category_type: 'platforms'))
      get category_type_path(category_type: 'platforms')
      expect(response).to have_http_status(:success)
      expect(response.body).to include(category_item_path(category_type: 'platforms', name: 'Nintendo Switch'))
    end

    it 'shows matching games and their media count' do
      get category_item_path(category_type: 'platforms', name: 'PC', type: 'video_games')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Portal', 'Video Games (1)')
    end

    it 'links each platform from game details' do
      get video_game_path(game)
      expect(response).to have_http_status(:success)
      ['PC', 'Nintendo Switch'].each do |platform|
        expect(response.body).to include(category_item_path(category_type: 'platforms', name: platform))
      end
    end
  end
end
