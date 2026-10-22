# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Owner library workspace navigation', type: :system do
  it 'connects profile management to shared workspaces and preserves state through repeated navigation' do
    owner = create_and_login_user
    owner.update!(username: 'library_reader')
    page.driver.browser.logs.get(:browser)
    26.times do |n|
      movie = Movie.create!(title: "Story #{n.to_s.rjust(2, '0')}", director: 'Fixture Director')
      owner.library_items.create!(item: movie, is_collected: true, owned_physically: true, rating: 4, is_public: false)
    end
    owner.library_items.create!(item: Book.create!(title: 'Story book'), is_collected: true)
    owner.library_items.create!(item: VideoGame.create!(title: 'Story game'), is_collected: true)
    %w[light dark].each do |theme|
      owner.update!(theme: theme)
      [320, 768, 1440].each do |width|
        resize_browser_viewport(width, 1000)
        visit handle_profile_path(owner.username, tab: 'collection')
        expect(page).to have_css('.owner-library-tools')
        page.scroll_to(find('.owner-library-tools'), align: :center)
        capture_ui_screenshot("owner-library-profile-#{theme}-#{width}")
        within('.owner-library-tools') { click_link 'Movies', exact: true }
        expect(page).to have_current_path(movies_path(library: 'mine'))
        expect(page).to have_css('.library-format-navigation a[aria-current="page"]', text: 'Movies')
        fill_in 'Search films', with: 'Story'
        select 'Title A–Z', from: 'Sort by'
        select 'Compact list', from: 'Display'
        click_button 'Apply', exact: true
        expect(page).to have_field('Search films', with: 'Story')
        expect(page).to have_css('.collection-list .card-2026', count: 24)
        expect(page).to have_text('4.0')
        find('.pagination .next a').click
        expect(page).to have_css('.card-2026', count: 2)
        filtered_url = page.current_url
        within('.library-switch') { click_link 'Browse catalog' }
        expect(page).to have_field('Search movies', with: 'Story')
        expect(page).to have_select('Sort by', selected: 'Title A–Z')
        page.go_back
        expect(page).to have_current_path(filtered_url, url: true)
        expect(page).to have_css('.collection-list .card-2026', count: 2)
        within('.library-format-navigation') { click_link 'Books', exact: true }
        expect(page).to have_field('Search books', with: 'Story')
        expect(page).to have_select('Display', selected: 'Compact list')
        expect(page).to have_css('.card-2026', count: 1)
        expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
        capture_ui_screenshot("owner-library-workspace-#{theme}-#{width}")
        within('.library-format-navigation') { click_link 'Games', exact: true }
        expect(page).to have_field('Search my games', with: 'Story')
        expect(page).to have_select('Display', selected: 'Compact list')
        expect(page).to have_text('Story game')
        within('.library-format-navigation') { click_link 'Library overview' }
        expect(page).to have_css('.owner-library-tools')
        expect(page.driver.browser.logs.get(:browser).select { |entry| entry.level == 'SEVERE' }).to be_empty
      end
    end
    visit handle_profile_path(owner.username, tab: 'backlog')
    expect(page).to have_css('.owner-library-tools')
    visit handle_profile_path(owner.username, tab: 'collection', preview: 'public')
    expect(page).to have_no_css('.owner-library-tools')
  end
end
