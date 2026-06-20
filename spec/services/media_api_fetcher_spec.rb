# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaApiFetcher do
  describe '.call' do
    let(:movie) { Movie.create!(title: 'The Matrix') }
    let(:tv_show) { TvShow.create!(title: 'Breaking Bad') }
    let(:album) { Album.create!(title: 'Abbey Road') }

    before do
      ApiConfiguration.create!(source_name: 'itunes', media_type: 'Movie', is_active: true)
      ApiConfiguration.create!(source_name: 'tvmaze', media_type: 'TvShow', is_active: true)
      ApiConfiguration.create!(source_name: 'itunes', media_type: 'Album', is_active: true)

      stub_request(:get, /itunes.apple.com/).to_return(
        status: 200,
        body: { results: [{ artistName: 'Lana Wachowski', releaseDate: '1999-03-31T07:00:00Z',
                            artworkUrl100: 'http://example.com/matrix.jpg' }] }.to_json
      )

      stub_request(:get, /api.tvmaze.com/).to_return(
        status: 200,
        body: [{ show: { network: { name: 'AMC' }, image: { medium: 'http://example.com/bb.jpg' } } }].to_json
      )

      stub_request(:get, /musicbrainz.org/).to_return(
        status: 200,
        body: { 'release-groups' => [] }.to_json
      )
    end

    it 'fetches movie data from iTunes' do
      described_class.call(movie)
      movie.reload
      expect(movie.director).to eq('Lana Wachowski')
      expect(movie.release_year).to eq(1999)
      expect(movie.thumbnail_url).to eq('http://example.com/matrix.jpg')
    end

    it 'fetches tv show data from TVMaze' do
      described_class.call(tv_show)
      tv_show.reload
      expect(tv_show.network).to eq('AMC')
      expect(tv_show.thumbnail_url).to eq('http://example.com/bb.jpg')
    end

    it 'fetches album data from iTunes' do
      described_class.call(album)
      album.reload
      expect(album.artist).to eq('Lana Wachowski') # stub is identical for all itunes calls
      expect(album.release_year).to eq(1999)
    end
  end
end
