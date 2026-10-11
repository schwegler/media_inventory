# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaRatingsHelper, type: :helper do
  let(:user) { User.create!(name: 'User 1', email: 'u1@example.com', password: 'password123') }
  let(:other_user) { User.create!(name: 'User 2', email: 'u2@example.com', password: 'password123') }
  let(:movie) { Movie.create!(title: 'Inception') }

  describe '#item_card_ratings' do
    it 'returns nil ratings for unrated items' do
      expect(helper.item_card_ratings(movie)).to eq({ user_rating: nil, avg_rating: nil })
    end

    it 'computes average rating from public library items when logged out' do
      LibraryItem.create!(user: other_user, item: movie, rating: '4.0', is_public: true)
      LibraryItem.create!(user: user, item: movie, rating: '5.0', is_public: true)

      allow(helper).to receive(:logged_in?).and_return(false)
      allow(helper).to receive(:current_user).and_return(nil)

      expect(helper.item_card_ratings(movie)).to eq({ user_rating: nil, avg_rating: 4.5 })
    end

    it 'includes the user rating and private user item in average when logged in' do
      LibraryItem.create!(user: other_user, item: movie, rating: '4.0', is_public: true)
      LibraryItem.create!(user: user, item: movie, rating: '5.0', is_public: false)

      allow(helper).to receive(:logged_in?).and_return(true)
      allow(helper).to receive(:current_user).and_return(user)

      expect(helper.item_card_ratings(movie)).to eq({ user_rating: '5.0', avg_rating: 4.5 })
    end

    it 'uses user_library if provided and belonging to current user' do
      lib = LibraryItem.create!(user: user, item: movie, rating: '3.5', is_public: true)

      allow(helper).to receive(:logged_in?).and_return(true)
      allow(helper).to receive(:current_user).and_return(user)

      expect(helper.item_card_ratings(movie, user_library: lib)).to eq({ user_rating: '3.5', avg_rating: 3.5 })
    end
  end
end
