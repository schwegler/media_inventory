# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Item card ratings', type: :request do
  let(:user) { User.create!(name: 'Alice', email: 'alice@example.com', password: 'password123') }
  let(:other_user) { User.create!(name: 'Bob', email: 'bob@example.com', password: 'password123') }
  let!(:movie) { Movie.create!(title: 'Rated Movie', release_year: 2024) }
  let!(:unrated_movie) { Movie.create!(title: 'Unrated Movie', release_year: 2024) }
  let!(:video_game) { VideoGame.create!(title: 'Rated Game', release_year: 2024, game_type: 'game') }

  before do
    LibraryItem.create!(user: other_user, item: movie, rating: '4.0', is_public: true)
    LibraryItem.create!(user: other_user, item: video_game, rating: '3.0', is_public: true)
  end

  context 'when guest visits catalog' do
    it 'surfaces avg rating on item cards but not user rating' do
      get movies_path
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)

      rated_card = document.at_css(".card-2026:has(a:contains('Rated Movie'))")
      expect(rated_card).to be_present
      expect(rated_card.css('.card-2026-ratings')).to be_present
      expect(rated_card.css('.card-2026-avg-rating').text).to include('4.0 ★')
      expect(rated_card.css('.card-2026-user-rating')).to be_empty

      unrated_card = document.at_css(".card-2026:has(a:contains('Unrated Movie'))")
      expect(unrated_card).to be_present
      expect(unrated_card.css('.card-2026-ratings')).to be_empty
    end
  end

  context 'when signed in user visits catalog' do
    before do
      LibraryItem.create!(user: user, item: movie, rating: '5.0', is_public: true)
      LibraryItem.create!(user: user, item: video_game, rating: '5.0', is_public: true)
      post login_path, params: { session: { email: user.email, password: 'password123' } }
    end

    it 'surfaces both user and avg ratings on media item cards' do
      get movies_path
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)

      rated_card = document.at_css(".card-2026:has(a:contains('Rated Movie'))")
      expect(rated_card).to be_present
      expect(rated_card.css('.card-2026-user-rating').text).to include('Yours')
      expect(rated_card.css('.card-2026-user-rating').text).to include('5.0 ★')
      expect(rated_card.css('.card-2026-avg-rating').text).to include('Avg')
      expect(rated_card.css('.card-2026-avg-rating').text).to include('4.5 ★')
    end

    it 'surfaces both user and avg ratings on video game cards in catalog' do
      get video_games_path
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)

      game_card = document.at_css(".card-2026:has(a:contains('Rated Game'))")
      expect(game_card).to be_present
      expect(game_card.css('.card-2026-user-rating').text).to include('Yours')
      expect(game_card.css('.card-2026-user-rating').text).to include('5.0 ★')
      expect(game_card.css('.card-2026-avg-rating').text).to include('Avg')
      expect(game_card.css('.card-2026-avg-rating').text).to include('4.0 ★')
    end

    it 'surfaces ratings in search results' do
      get search_path(q: 'Rated')
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)

      movie_card = document.at_css(".card-2026:has(a:contains('Rated Movie'))")
      expect(movie_card).to be_present
      expect(movie_card.css('.card-2026-user-rating').text).to include('Yours')
      expect(movie_card.css('.card-2026-avg-rating').text).to include('4.5 ★')
    end

    it 'preloads library items for preloaded records to prevent N+1 queries during card rendering' do
      items = LibraryItem.where(user: user, item: [movie, video_game]).to_a
      dummy_controller = Class.new { include RecordPreloader }.new
      dummy_controller.send(:preload_library_items, items)

      preloaded_media = items.map(&:item)
      expect(preloaded_media.all? { |media| media.association(:library_items).loaded? }).to be true
    end
  end
end
