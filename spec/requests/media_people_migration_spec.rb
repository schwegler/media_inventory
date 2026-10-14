# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Media People Migration', type: :request do
  describe 'Books' do
    let!(:book) { Book.create!(title: 'The Dispossessed', author: 'Ursula K. Le Guin', publisher: 'Harper & Row') }

    it 'syncs authors to MetadataEntity and links on show page' do
      expect(book.metadata_entities.pluck(:name)).to include('Ursula K. Le Guin')
      get book_path(book)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Ursula K. Le Guin')
      expect(response.body).to include('/entities/')
    end

    it 'returns book when searching author name' do
      results = MetadataSearch.call(Book.all, 'Ursula K. Le Guin')
      expect(results).to include(book)
    end
  end

  describe 'Movies' do
    let!(:movie) do
      Movie.create!(title: 'Inception', director: 'Christopher Nolan', writer: 'Christopher Nolan',
                    actors: 'Leonardo DiCaprio, Joseph Gordon-Levitt')
    end

    it 'syncs movie director and cast to MetadataEntity and links on show page' do
      expect(movie.metadata_entities.pluck(:name)).to include('Christopher Nolan', 'Leonardo DiCaprio',
                                                              'Joseph Gordon-Levitt')
      get movie_path(movie)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Christopher Nolan')
      expect(response.body).to include('/entities/')
    end

    it 'returns movie when searching actor name' do
      results = MetadataSearch.call(Movie.all, 'Leonardo DiCaprio')
      expect(results).to include(movie)
    end
  end
end
