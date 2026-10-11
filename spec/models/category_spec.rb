# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Category, type: :model do
  describe '.split_names' do
    it 'splits comma, semicolon, slash, and pipe separated names' do
      names_string = 'Keanu Reeves, Laurence Fishburne; Carrie-Anne Moss / Hugo Weaving | Joe Pantoliano'
      expect(Category.split_names(names_string)).to eq(
        ['Keanu Reeves', 'Laurence Fishburne', 'Carrie-Anne Moss', 'Hugo Weaving', 'Joe Pantoliano']
      )
    end

    it 'returns empty array for blank input' do
      expect(Category.split_names(nil)).to eq([])
      expect(Category.split_names('')).to eq([])
      expect(Category.split_names('   ')).to eq([])
    end
  end

  describe '.list_for' do
    before do
      Movie.create!(title: 'The Matrix', director: 'Lana Wachowski, Lilly Wachowski',
                    writer: 'Lana Wachowski, Lilly Wachowski', actors: 'Keanu Reeves, Laurence Fishburne',
                    genre: 'Action, Sci-Fi')
      Movie.create!(title: 'John Wick', director: 'Chad Stahelski', writer: 'Derek Kolstad',
                    actors: 'Keanu Reeves, Michael Nyqvist', genre: 'Action, Thriller')
      TvShow.create!(title: 'Sense8', director: 'Lana Wachowski', writer: 'Lana Wachowski, J. Michael Straczynski',
                     actors: 'Doona Bae, Jamie Clayton', genre: 'Sci-Fi, Drama')
    end

    it 'aggregates and counts actors across movies and tv shows' do
      actors = Category.list_for('actors')
      keanu = actors.find { |a| a.name == 'Keanu Reeves' }
      expect(keanu).not_to be_nil
      expect(keanu.count).to eq(2)

      doona = actors.find { |a| a.name == 'Doona Bae' }
      expect(doona).not_to be_nil
      expect(doona.count).to eq(1)
    end

    it 'aggregates and counts directors across movies and tv shows' do
      directors = Category.list_for('directors')
      lana = directors.find { |d| d.name == 'Lana Wachowski' }
      expect(lana).not_to be_nil
      expect(lana.count).to eq(2)
    end

    it 'aggregates and counts genres across media' do
      genres = Category.list_for('genres')
      scifi = genres.find { |g| g.name == 'Sci-Fi' }
      action = genres.find { |g| g.name == 'Action' }
      expect(scifi.count).to eq(2)
      expect(action.count).to eq(2)
    end

    it 'supports filtering by query' do
      filtered = Category.list_for('actors', query: 'keanu')
      expect(filtered.map(&:name)).to eq(['Keanu Reeves'])
    end

    it 'supports sorting by name A-Z' do
      sorted = Category.list_for('genres', sort: :name)
      names = sorted.map(&:name)
      expect(names).to eq(names.sort_by(&:downcase))
    end
  end

  describe '.items_for' do
    let!(:matrix) do
      Movie.create!(title: 'The Matrix', release_year: 1999, director: 'Lana Wachowski',
                    writer: 'Lana Wachowski', actors: 'Keanu Reeves, Laurence Fishburne', genre: 'Sci-Fi')
    end
    let!(:wick) do
      Movie.create!(title: 'John Wick', release_year: 2014, director: 'Chad Stahelski',
                    writer: 'Derek Kolstad', actors: 'Keanu Reeves', genre: 'Action')
    end
    let!(:sense8) do
      TvShow.create!(title: 'Sense8', release_year: 2015, director: 'Lana Wachowski',
                     writer: 'Lana Wachowski', actors: 'Doona Bae', genre: 'Sci-Fi')
    end

    it 'finds all items matching an actor' do
      items = Category.items_for('actors', 'Keanu Reeves')
      expect(items).to match_array([matrix, wick])
    end

    it 'finds all items matching a director across movies and TV' do
      items = Category.items_for('directors', 'Lana Wachowski')
      expect(items).to match_array([matrix, sense8])
    end

    it 'filters by media_type' do
      movie_items = Category.items_for('directors', 'Lana Wachowski', media_type: 'movies')
      expect(movie_items).to eq([matrix])

      tv_items = Category.items_for('directors', 'Lana Wachowski', media_type: 'tv_shows')
      expect(tv_items).to eq([sense8])
    end

    it 'sorts items by release year' do
      items = Category.items_for('actors', 'Keanu Reeves', sort: 'year')
      expect(items).to eq([wick, matrix])
    end

    it 'sorts items by title' do
      items = Category.items_for('actors', 'Keanu Reeves', sort: 'title')
      expect(items).to eq([wick, matrix])
    end
  end
  describe 'video game platforms' do
    let!(:game) { VideoGame.create!(title: 'Portal', platform: 'PC, Nintendo Switch') }
    let!(:other_game) { VideoGame.create!(title: 'Portal 2', platform: 'pc; PlayStation 3') }

    it 'aggregates platforms case-insensitively and supports search' do
      platforms = Category.list_for('platforms', query: 'pc')
      expect(platforms.map(&:name)).to eq(['PC'])
      expect(platforms.first.count).to eq(2)
    end

    it 'matches whole platform names and filters by media type' do
      expect(Category.items_for('platforms', 'PC', media_type: 'video_games')).to match_array([game, other_game])
      expect(Category.items_for('platforms', 'Nintendo')).to be_empty
      expect(Category.items_for('platforms', 'PC', media_type: 'movies')).to be_empty
    end
  end
end
