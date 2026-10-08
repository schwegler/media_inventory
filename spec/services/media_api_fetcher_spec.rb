# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaApiFetcher do
  before { MediaSources::Registry::CACHE.clear }

  it 'combines missing metadata from matching sources without overwriting edits' do
    item = Movie.create!(title: 'The Matrix', director: 'My edit')
    allow(MediaSearchService).to receive(:call).and_return([
                                                             { title: 'The Matrix', director: 'API director',
                                                               release_year: 1999 },
                                                             { title: 'The Matrix',
                                                               external_url: 'https://www.themoviedb.org/movie/603' },
                                                             { title: 'Matrix Reloaded', release_year: 2003 }
                                                           ])
    described_class.call(item)
    expect(item.reload.director).to eq('My edit')
    expect(item.release_year).to eq(1999)
    expect(item.external_url).to eq('https://www.themoviedb.org/movie/603')
  end

  it 'does not merge a different release of the same title' do
    item = Movie.create!(title: 'Dune', release_year: 1984)
    allow(MediaSearchService).to receive(:call).and_return([{ title: 'Dune', release_year: 2021,
                                                              director: 'Wrong director' }])
    described_class.call(item)
    expect(item.reload.director).to be_blank
  end
end
