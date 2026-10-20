# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Title section navigation', type: :system do
  it 'uses local anchors immediately without fetching or replacing the title page' do
    show = TvShow.create!(title: 'Section navigation fixture', network: 'Fixture network', writer: 'A long overview. ' * 100)
    8.times { |i| show.tv_episodes.create!(name: "Episode #{i + 1}", season: 1, episode: i + 1) }
    visit tv_show_path(show)
    expect(page).to have_css('.media-section-nav a[aria-current]')
    page.execute_script(<<~JS)
      window.sectionRequests = 0;
      document.addEventListener('turbo:before-fetch-request', () => window.sectionRequests++);
      window.originalTitle = document.querySelector('.media-detail');
    JS
    find('.media-section-nav a[href="#title-details"]').click
    expect(page).to have_current_path(tv_show_path(show)) { |uri| uri.fragment == "title-details" }
    expect(page.evaluate_script('window.sectionRequests')).to eq(0)
    expect(page.evaluate_script('window.originalTitle === document.querySelector(".media-detail")')).to be true
    expect(page.evaluate_script('document.querySelector("#title-details").getBoundingClientRect().top')).to be_between(90, 140)
  end
end
