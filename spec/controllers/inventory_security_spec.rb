require 'rails_helper'

RSpec.describe MoviesController, type: :controller do
  include SessionsHelper

  let(:user) { User.create!(name: 'Standard User', password: 'password', confirmed_at: Time.current) }
  let(:admin) { User.create!(name: 'Admin User', password: 'password', confirmed_at: Time.current, admin: true) }
  let!(:movie) { Movie.create!(title: 'Existing Movie', api_id: '123') }

  describe "PATCH #update" do
    context "as a standard user" do
      before do
        session[:user_id] = user.id
      end

      it "does not allow updating global metadata of an existing movie" do
        patch :update, params: { id: movie.id, movie: { title: 'Hacked Title' } }
        movie.reload
        expect(movie.title).to eq('Existing Movie')
      end

      it "allows updating library metadata" do
        patch :update, params: { id: movie.id, movie: { rating: '5.0', review: 'Great!' } }
        library_item = LibraryItem.find_by(user: user, item: movie)
        expect(library_item.rating.to_f).to eq(5.0)
        expect(library_item.review).to eq('Great!')
      end
    end

    context "as an admin" do
      before do
        session[:user_id] = admin.id
      end

      it "allows updating global metadata" do
        patch :update, params: { id: movie.id, movie: { title: 'Updated Title' } }
        movie.reload
        expect(movie.title).to eq('Updated Title')
      end
    end
  end

  describe "POST #create" do
    context "as a standard user" do
      before do
        session[:user_id] = user.id
      end

      it "does not allow updating global metadata if api_id matches existing movie" do
        post :create, params: { movie: { api_id: '123', title: 'Hacked Title' } }
        movie.reload
        expect(movie.title).to eq('Existing Movie')
      end

      it "allows creating a new movie with global metadata" do
        post :create, params: { movie: { title: 'New Movie', api_id: '456' } }
        new_movie = Movie.find_by(api_id: '456')
        expect(new_movie.title).to eq('New Movie')
      end
    end
  end
end
