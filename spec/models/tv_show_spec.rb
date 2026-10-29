# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TvShow, type: :model do
  it 'is valid with a title' do
    tv_show = TvShow.new(title: 'Breaking Bad')
    expect(tv_show).to be_valid
  end

  it 'is invalid without a title' do
    tv_show = TvShow.new(title: nil)
    expect(tv_show).to_not be_valid
  end

  it 'persists rich details (network, release_year, director, writer, actors, genre)' do
    tv_show = TvShow.create!(
      title: '30 Rock',
      network: 'NBC',
      release_year: 2006,
      director: 'Don Scardino',
      writer: 'Tina Fey',
      actors: 'Tina Fey, Alec Baldwin, Tracy Morgan, Jane Krakowski',
      genre: 'Comedy'
    )
    expect(tv_show.reload.network).to eq('NBC')
    expect(tv_show.release_year).to eq(2006)
    expect(tv_show.director).to eq('Don Scardino')
    expect(tv_show.writer).to eq('Tina Fey')
    expect(tv_show.actors).to eq('Tina Fey, Alec Baldwin, Tracy Morgan, Jane Krakowski')
    expect(tv_show.genre).to eq('Comedy')
  end

  it 'syncs rich details from TVMaze on episode sync' do
    stub_request(:get, 'https://api.tvmaze.com/shows/537?embed[]=cast&embed[]=crew')
      .to_return(body: {
        name: '30 Rock',
        premiered: '2006-10-11',
        genres: ['Comedy'],
        _embedded: {
          cast: [
            { person: { name: 'Tina Fey' } },
            { person: { name: 'Alec Baldwin' } }
          ],
          crew: [
            { type: 'Creator', person: { name: 'Tina Fey' } },
            { type: 'Director', person: { name: 'Don Scardino' } }
          ]
        }
      }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, 'https://api.tvmaze.com/shows/537/episodes?specials=1')
      .to_return(body: [
        { id: 1, name: 'Pilot', season: 1, number: 1, airdate: '2006-10-11' }
      ].to_json, headers: { 'Content-Type' => 'application/json' })

    tv_show = TvShow.create!(title: '30 Rock', api_id: '537')
    tv_show.send(:sync_episodes_from_api)

    expect(tv_show.reload.writer).to eq('Tina Fey')
    expect(tv_show.director).to eq('Don Scardino')
    expect(tv_show.actors).to eq('Tina Fey, Alec Baldwin')
    expect(tv_show.genre).to eq('Comedy')
    expect(tv_show.release_year).to eq(2006)
  end
  it 'imports unnumbered specials in the initial TVMaze sync without assigning episode numbers' do
    special = { id: 3_684_533, name: 'Halloween 6: The Mirror – Parts One & Two',
                season: 6, number: nil, type: 'significant_special', airdate: '2026-10-29' }
    stub_request(:get, 'https://api.tvmaze.com/shows/46573/episodes?specials=1')
      .to_return(body: [special].to_json)
    show = TvShow.create!(title: 'Ghosts', api_id: '46573')
    show.send(:sync_episodes_from_api)
    episode = show.tv_episodes.sole
    expect(episode.episode).to be_nil
    expect(episode.season).to eq(6)
    expect(episode.provider_id).to eq('3684533')
    expect(episode.metadata_details['Episode type']).to eq('significant_special')
  end
end
