# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Title metadata priority', type: :request do
  it 'consolidates linked people and additional roles into the appropriate metadata categories' do
    movie = Movie.create!(title: 'Credits hierarchy fixture', director: 'Director One', actors: 'Actor One',
                          metadata_credits_data: [{ 'name' => 'Director One', 'role' => 'Director' },
                                                  { 'name' => 'Actor One', 'role' => 'Actor' },
                                                  { 'name' => 'Composer One', 'role' => 'Composer' }])
    get movie_path(movie)
    document = Nokogiri::HTML(response.body)
    facts = document.at_css('#title-details')
    expect(facts.css('a').map(&:text)).to include('Director One', 'Actor One')
    expect(document.at_css('#metadata-creators').css('a').map(&:text)).to include('Director One', 'Composer One')
    expect(facts.text.scan('Composer One').length).to eq(1)
    expect(document.at_css('.media-overview-stats')).to be_present
    expect(document.at_css('#community')).to be_present
  end

  it 'retains structured roles when there is no corresponding legacy detail field' do
    movie = Movie.create!(title: 'Structured-only fixture',
                          metadata_credits_data: [{ 'name' => 'Actor One', 'role' => 'Actor' }])
    get movie_path(movie)
    expect(Nokogiri::HTML(response.body).at_css('#metadata-cast').text).to include('Actor One')
  end
end
