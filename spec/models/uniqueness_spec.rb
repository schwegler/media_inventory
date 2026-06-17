# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Uniqueness', type: :model do
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com', password: 'password') }

  describe 'TvShow' do
    it 'prevents duplicate TV shows by api_id for the same user' do
      TvShow.create!(title: 'Show 1', api_id: '123', user: user)
      duplicate = TvShow.new(title: 'Show 1 Duplicate', api_id: '123', user: user)
      expect(duplicate).not_to be_valid
    end

    it 'prevents duplicate TV shows by title for the same user when api_id is blank' do
      TvShow.create!(title: 'Unique Show', user: user)
      duplicate = TvShow.new(title: 'Unique Show', user: user)
      expect(duplicate).not_to be_valid
    end
  end

  describe 'Movie' do
    it 'prevents duplicate movies by api_id for the same user' do
      Movie.create!(title: 'Movie 1', api_id: 'm123', user: user)
      duplicate = Movie.new(title: 'Movie 1 Duplicate', api_id: 'm123', user: user)
      expect(duplicate).not_to be_valid
    end

    it 'prevents duplicate movies by title and release_year for the same user when api_id is blank' do
      Movie.create!(title: 'Unique Movie', release_year: 2024, user: user)
      duplicate = Movie.new(title: 'Unique Movie', release_year: 2024, user: user)
      expect(duplicate).not_to be_valid
    end
  end

  describe 'Album' do
    it 'prevents duplicate albums by api_id for the same user' do
      Album.create!(title: 'Album 1', api_id: 'a123', user: user)
      duplicate = Album.new(title: 'Album 1 Duplicate', api_id: 'a123', user: user)
      expect(duplicate).not_to be_valid
    end

    it 'prevents duplicate albums by title and artist for the same user when api_id is blank' do
      Album.create!(title: 'Unique Album', artist: 'Artist 1', user: user)
      duplicate = Album.new(title: 'Unique Album', artist: 'Artist 1', user: user)
      expect(duplicate).not_to be_valid
    end
  end

  describe 'Comic' do
    it 'prevents duplicate comics by api_id for the same user' do
      Comic.create!(title: 'Comic 1', api_id: 'c123', user: user)
      duplicate = Comic.new(title: 'Comic 1 Duplicate', api_id: 'c123', user: user)
      expect(duplicate).not_to be_valid
    end

    it 'prevents duplicate comics by title and issue_number for the same user when api_id is blank' do
      Comic.create!(title: 'Unique Comic', issue_number: 1, user: user)
      duplicate = Comic.new(title: 'Unique Comic', issue_number: 1, user: user)
      expect(duplicate).not_to be_valid
    end
  end

  describe 'VideoGame' do
    it 'prevents duplicate video games by api_id for the same user' do
      VideoGame.create!(title: 'Game 1', api_id: 'g123', user: user)
      duplicate = VideoGame.new(title: 'Game 1 Duplicate', api_id: 'g123', user: user)
      expect(duplicate).not_to be_valid
    end

    it 'prevents duplicate video games by title and platform for the same user when api_id is blank' do
      VideoGame.create!(title: 'Unique Game', platform: 'PC', user: user)
      duplicate = VideoGame.new(title: 'Unique Game', platform: 'PC', user: user)
      expect(duplicate).not_to be_valid
    end
  end
end
