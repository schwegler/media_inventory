# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoviesController, type: :controller do
  let(:admin) { User.create!(name: 'Admin', email: 'admin@example.com', password: 'password', admin: true) }
  let(:user) { User.create!(name: 'User', email: 'user@example.com', password: 'password', admin: false) }
  let(:movie) { Movie.create!(title: 'Original Title', director: 'Original Director') }

  describe 'PATCH #update security' do
    context 'as a non-admin user' do
      before do
        session[:user_id] = user.id
      end

      it 'does not allow updating global metadata' do
        patch :update, params: { id: movie.id, movie: { title: 'Hacked Title', director: 'Hacked Director' } }

        movie.reload
        expect(movie.title).to eq('Original Title')
        expect(movie.director).to eq('Original Director')
      end

      it 'allows updating library item metadata' do
        patch :update, params: { id: movie.id, movie: { rating: '5', review: 'Great!' } }

        library_item = LibraryItem.find_by(user: user, item: movie)
        expect(library_item.rating).to eq('5')
        expect(library_item.review).to eq('Great!')
      end
    end

    context 'as an admin user' do
      before do
        session[:user_id] = admin.id
      end

      it 'allows updating global metadata' do
        patch :update, params: { id: movie.id, movie: { title: 'Admin Updated Title' } }

        movie.reload
        expect(movie.title).to eq('Admin Updated Title')
      end
    end
  end

  describe 'POST #create security' do
    context 'as a guest' do
      it 'redirects to login' do
        post :create, params: { movie: { title: 'New Movie' } }
        expect(response).to redirect_to(login_url)
      end
    end
  end
end
