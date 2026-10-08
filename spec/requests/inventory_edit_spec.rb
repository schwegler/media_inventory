# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Catalog editing', type: :request do
  let(:user) { User.create!(name: 'Reader', email: 'reader@example.test', password: 'password') }
  let(:movie) { Movie.create!(title: 'A movie') }

  before { post login_path, params: { session: { email: user.email, password: 'password' } } }

  it 'renders the shared edit form for an existing library item' do
    LibraryItem.create!(user: user, item: movie, is_collected: true, review: 'My review')
    get edit_movie_path(movie)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('My review', 'Save changes')
    patch movie_path(movie), params: { movie: { review: 'Updated review' } }
    expect(LibraryItem.find_by(user: user, item: movie).review).to eq('Updated review')
  end

  it 'does not expose the edit form to a member without a library entry' do
    get edit_movie_path(movie)
    expect(response).to redirect_to(root_path)
  end
end
