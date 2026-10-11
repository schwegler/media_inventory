# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Movie, type: :model do
  it 'is valid with a title' do
    movie = Movie.new(title: 'Inception')
    expect(movie).to be_valid
  end

  it 'is invalid without a title' do
    movie = Movie.new(title: nil)
    expect(movie).to_not be_valid
  end

  it 'persists rich details (director, writer, actors, genre)' do
    movie = Movie.create!(
      title: 'Fight Club',
      release_year: 1999,
      director: 'David Fincher',
      writer: 'Chuck Palahniuk, Jim Uhls',
      actors: 'Edward Norton, Brad Pitt, Helena Bonham Carter',
      genre: 'Drama, Thriller'
    )
    expect(movie.reload.director).to eq('David Fincher')
    expect(movie.writer).to eq('Chuck Palahniuk, Jim Uhls')
    expect(movie.actors).to eq('Edward Norton, Brad Pitt, Helena Bonham Carter')
    expect(movie.genre).to eq('Drama, Thriller')
  end

  it 'syncs rich details from TMDB on create or api_id change' do
    ApiConfiguration.create!(source_name: 'TMDB', media_type: 'Movie', is_active: true, access_token: 'valid_token')
    stub_request(:get, 'https://api.themoviedb.org/3/movie/550?api_key=valid_token&append_to_response=credits')
      .to_return(body: {
        title: 'Fight Club',
        release_date: '1999-10-15',
        poster_path: '/poster.jpg',
        genres: [{ id: 18, name: 'Drama' }, { id: 53, name: 'Thriller' }],
        credits: {
          crew: [
            { name: 'David Fincher', job: 'Director' },
            { name: 'Jim Uhls', department: 'Writing' }
          ],
          cast: [
            { name: 'Edward Norton' },
            { name: 'Brad Pitt' }
          ]
        }
      }.to_json, headers: { 'Content-Type' => 'application/json' })

    movie = Movie.create!(title: 'Fight Club', api_id: '550')
    expect(movie.reload.director).to eq('David Fincher')
    expect(movie.writer).to eq('Jim Uhls')
    expect(movie.actors).to eq('Edward Norton, Brad Pitt')
    expect(movie.genre).to eq('Drama, Thriller')
    expect(movie.release_year).to eq(1999)
  end
end
