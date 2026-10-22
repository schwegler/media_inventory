# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Calendar-year episode navigation', type: :system do
  it 'keeps real year-numbered seasons across pagination and browser Back on desktop and mobile' do
    show = TvShow.create!(title: 'Calendar-year soap fixture')
    TvEpisode.insert_all!(7333.times.map do |n|
      { tv_show_id: show.id, season: 1985 + (n / 175), episode: (n % 175) + 1, name: "Chapter #{n + 1}" }
    end)
    [1440, 390].each do |width|
      resize_browser_viewport(width, 1000)
      visit tv_show_path(show, season: '2026')
      expect(page).to have_css('[data-controller="series-navigation"][data-connected="true"]')
      expect(page).to have_select('Season', selected: 'Season 2026')
      expect(page).to have_text('158 matching episodes')
      expect(page).to have_css('#series-entries .series-entry', count: 30)
      find('.series-pagination a[rel="next"]').click
      expect(page).to have_css('.series-pagination-count', text: '31–60 of 158 episodes')
      expect(page).to have_select('Season', selected: 'Season 2026')
      expect(URI.parse(page.current_url).fragment).to eq('media-entries')
      page.scroll_to(find('.series-pagination'), align: :center)
      capture_ui_screenshot("soap-year-pagination-#{width}")
      page.go_back
      expect(page).to have_css('.series-pagination-count', text: '1–30 of 158 episodes')
      expect(page).to have_select('Season', selected: 'Season 2026')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
    end
  end
end
