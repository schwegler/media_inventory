# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Search continuation', type: :request do
  it 'reaches result 21, preserves type/query and exposes selected filter state' do
    Movie.insert_all!(25.times.map { |i| { title: format('Continuation %02d', i) } })
    get search_path(q: 'Continuation')
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("button[name='type'][value='']")['aria-pressed']).to eq('true')
    expect(page.at_css("a[href='#{search_path(q: 'Continuation', type: 'movies')}']")).to be_present
    get search_path(q: 'Continuation', type: 'movies', page: 2)
    expect(response.body).to include('Continuation 20', 'Continuation 24')
    expect(response.body).not_to include('Continuation 00')
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("button[value='movies']")['aria-pressed']).to eq('true')
    expect(page.css('.card-2026').size).to eq(5)
    expect(page.css('nav.pagination a').map { |link| link['href'] }.join).to include('q=Continuation', 'type=movies')
  end

  it 'normalizes unsupported types and provides a reset for an out-of-range page' do
    Movie.create!(title: 'Needle')
    get search_path(q: 'Needle', type: 'unknown')
    expect(response.body).to include('Needle')
    get search_path(q: 'Needle', type: 'movies', page: 999)
    expect(response.body).to include('Search all types from the first page')
  end
end
