# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Large child collections', type: :system do
  it 'bounds the DOM while preserving season, search and pagination through real requests' do
    series = TvShow.create!(title: 'Large collection')
    TvEpisode.insert_all!(100.times.map do |index|
      { tv_show_id: series.id, name: "Episode #{index + 1}", season: index < 60 ? 1 : 2, episode: index + 1 }
    end)
    visit tv_show_path(series)
    expect(page).to have_css('[data-controller="series-navigation"][data-connected="true"]')
    expect(page).to have_text('60 matching episodes')
    expect(page).to have_css('#series-entries .series-entry', count: 30)
    fill_in 'Search episodes', with: 'Episode 12'
    expect(page).to have_text('1 matching episodes')
    expect(page).to have_css('#series-entries .series-entry', count: 1)
    fill_in 'Search episodes', with: ''
    expect(page).to have_text('60 matching episodes')
    select 'Season 2', from: 'Season'
    expect(page).to have_text('40 matching episodes')
    find('#series-entries .pagination .next a').click
    expect(page).to have_css('#series-entries .series-entry', count: 10)
    page.refresh
    expect(page).to have_select('Season', selected: 'Season 2')
    expect(page).to have_css('#series-entries .series-entry', count: 10)
    page.current_window.resize_to(390, 844)
    fill_in 'Search episodes', with: 'no such episode'
    expect(page).to have_text('No matching episodes.')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
  end
end
