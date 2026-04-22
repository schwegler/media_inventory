# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Movies', type: :request do
  let!(:user) do
    User.create(name: 'Example User', email: 'user@example.com', password: 'password',
                password_confirmation: 'password')
  end

  describe 'GET /movies' do
    it 'works! (now write some real specs)' do
      get movies_path
      expect(response).to have_http_status(200)
    end

    context 'with pagination' do
      before do
        30.times { |i| Movie.create!(title: "Movie #{i}") }
      end

      it 'returns the first page of movies' do
        get movies_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Movie 0')
        expect(response.body).to include('Movie 24')
        expect(response.body).not_to include('Movie 25')
      end

      it 'returns the second page of movies' do
        get movies_path(page: 2)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('Movie 0')
        expect(response.body).to include('Movie 25')
        expect(response.body).to include('Movie 29')
      end
    end
  end

  describe 'GET /movies/new' do
    context 'when not logged in' do
      it 'redirects to login' do
        get new_movie_path
        expect(response).to redirect_to(login_path)
      end
    end

    context 'when logged in' do
      before do
        post login_path, params: { session: { email: user.email, password: user.password } }
      end

      it 'returns http success' do
        get new_movie_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST /movies' do
    context 'when not logged in' do
      it 'redirects to login' do
        post movies_path, params: { movie: { title: 'New Movie' } }
        expect(response).to redirect_to(login_path)
      end
    end

    context 'when logged in' do
      before do
        post login_path, params: { session: { email: user.email, password: user.password } }
      end

      context 'with valid parameters' do
        it 'creates a new movie' do
          expect do
            post movies_path, params: { movie: { title: 'New Movie' } }
          end.to change(Movie, :count).by(1)
          expect(response).to redirect_to(Movie.last)
        end
      end

      context 'with invalid parameters' do
        it 'does not create a new movie' do
          expect do
            post movies_path, params: { movie: { title: '' } }
          end.not_to change(Movie, :count)
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include('New Movie')
        end
      end
    end
  end

  describe 'GET /movies/:id' do
    context 'with a valid movie' do
      let!(:movie) do
        Movie.create!(
          title: 'Inception',
          director: 'Christopher Nolan',
          release_year: 2010,
          rating: 'PG-13'
        )
      end

      it 'returns a success response and displays the movie details' do
        get movie_path(movie)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Inception')
        expect(response.body).to include('Christopher Nolan')
        expect(response.body).to include('2010')
        expect(response.body).to include('PG-13')
      end
    end

    context 'with an invalid movie id' do
      it 'returns a not found response' do
        get movie_path('0')
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
