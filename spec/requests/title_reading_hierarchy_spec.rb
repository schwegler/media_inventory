# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Title metadata priority', type: :request do
  it 'keeps linked people in title details and shows only additional roles in the credit section' do
    movie = Movie.create!(title: 'Credits hierarchy fixture', director: 'Director One', actors: 'Actor One',
                          metadata_credits_data: [{ 'name' => 'Director One', 'role' => 'Director' },
                                                  { 'name' => 'Actor One', 'role' => 'Actor' },
                                                  { 'name' => 'Composer One', 'role' => 'Composer' }])
    get movie_path(movie)
    document = Nokogiri::HTML(response.body)
    facts = document.at_css('#title-details')
    expect(facts.css('a').map(&:text)).to include('Director One', 'Actor One')
    additional = document.at_css('.entity-credits')
    expect(additional.css('a').map(&:text)).to eq(['Composer One'])
    expect(document.at_css('.media-overview-stats')).to be_present
    expect(document.at_css('#community')).to be_present
  end

  it 'retains structured roles when there is no corresponding legacy detail field' do
    movie = Movie.create!(title: 'Structured-only fixture',
                          metadata_credits_data: [{ 'name' => 'Actor One', 'role' => 'Actor' }])
    get movie_path(movie)
    expect(Nokogiri::HTML(response.body).at_css('.entity-credits').text).to include('Actor One')
  end
end
