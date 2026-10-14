# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Favorite shelves', type: :request do
  let(:user) { User.create!(name: 'Shelf User', username: 'shelf_user', email: 'shelf@example.com', password: 'password') }
  let(:movie) { Movie.create!(title: 'A favorite') }

  def login
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  it 'resolves handles and redirects legacy profile links while preserving tabs' do
    get handle_profile_path(user.username)
    expect(response).to have_http_status(:ok)
    get user_path(user, tab: 'collection')
    expect(response).to redirect_to(handle_profile_path(user.username, tab: 'collection'))
  end

  it 'saves ranked picks and renders a public shelf without review content' do
    login
    patch shelf_path(user.username, category: 'Movie'), params: { picks: [{ type: 'Movie', id: movie.id }] }, as: :json
    expect(response).to have_http_status(:ok)
    expect(user.favorite_shelves.find_by!(category: 'Movie').items).to eq([movie])
    delete logout_path
    get shelf_path(user.username, category: 'Movie')
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('A favorite', 'Download share image')
    expect(response.body).not_to include('Save shelf')
  end

  it 'rejects another user modifying the shelf' do
    login
    other = User.create!(name: 'Other', username: 'other', password: 'password')
    patch shelf_path(other.username, category: 'overall'), params: { picks: [] }, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'rejects duplicates, overfull shelves, and wrong media types' do
    login
    pick = { type: 'Movie', id: movie.id }
    [[pick, pick], Array.new(6, pick)].each do |picks|
      patch shelf_path(user.username, category: 'overall'), params: { picks: picks }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
    patch shelf_path(user.username, category: 'Book'), params: { picks: [pick] }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'searches the catalog with media filtering' do
    login
    movie
    get search_shelves_path(category: 'Movie', q: 'favorite')
    expect(response.parsed_body.first['title']).to eq('A favorite')
    get search_shelves_path(category: 'Book', q: 'favorite')
    expect(response.parsed_body).to eq([])
  end
end
