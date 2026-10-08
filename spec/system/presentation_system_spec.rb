# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Presentation and keyboard access', type: :system do
  before { page.current_window.resize_to(1440, 1000) }

  it 'keeps item navigation compact when scrolling and restores account menu focus' do
    create_and_login_user
    movie = Movie.create!(title: 'Compact header')
    visit movie_path(movie)
    expect(page).to have_css('[data-controller="mobile-menu"][data-connected="true"]')
    page.execute_script('window.scrollTo(0, 400)')
    pinned_bottom = page.evaluate_script('document.querySelector(".app-header").getBoundingClientRect().bottom')
    expect(pinned_bottom).to be <= 80
    click_button 'Open account and navigation menu'
    expect(page).to have_link('Settings', visible: true)
    page.driver.browser.action.send_keys(:escape).perform
    focused_label = page.evaluate_script('document.activeElement.getAttribute("aria-label")')
    expect(focused_label).to eq('Open account and navigation menu')
    expect(page).to have_css('.compact-menu-btn[aria-expanded="false"]')
  end

  it 'supports narrow navigation, restores menu focus, and previews and persists profile themes' do
    user = create_and_login_user
    page.current_window.resize_to(390, 844)
    visit movies_path
    expect(page).to have_css('[data-controller="mobile-menu"][data-connected="true"]')
    click_button 'Toggle navigation'
    expect(page).to have_link('Settings', visible: true)
    page.find('[data-mobile-menu-target="button"]').send_keys(:escape)
    expect(page).to have_css('[data-mobile-menu-target="button"][aria-expanded="false"]')
    expect(page.evaluate_script('document.activeElement.getAttribute("data-mobile-menu-target")')).to eq('button')
    visit settings_appearance_path
    expect(page).to have_css('[data-controller="appearance"][data-connected="true"]')
    select 'Garden moss', from: 'Profile accent'
    select 'Solid', from: 'Header treatment'
    expect(page).to have_css('.profile-preview[data-profile-accent="moss"][data-profile-header="solid"]')
    select 'Dark', from: 'Appearance'
    click_button 'Save preferences'
    expect(page).to have_content('Appearance preferences saved.')
    expect(page).to have_css('html[data-theme="dark"]')
    expect(user.reload.theme).to eq('dark')
    expect(user.profile_accent).to eq('moss')
  end

  it 'supports keyboard menus, a modal focus trap and focus restoration' do
    create_and_login_user
    visit movies_path
    expect(page).to have_css('[data-controller="dropdown"][data-connected="true"]')
    click_button 'Toggle log menu'
    expect(page.evaluate_script('document.activeElement.textContent')).to include('Log Movie')
    page.driver.browser.action.send_keys(:arrow_down).perform
    expect(page.evaluate_script('document.activeElement.textContent')).to include('Log Album')
    page.driver.browser.action.send_keys(:escape).perform
    expect(page.evaluate_script('document.activeElement.getAttribute("aria-label")')).to eq('Toggle log menu')
    click_button 'Toggle log menu'
    click_link '🎬 Log Movie'
    expect(page).to have_css('[role="dialog"][aria-modal="true"]')
    expect(page).to have_css('[data-controller="modal"][data-connected="true"]')
    expect(page.evaluate_script('document.activeElement.closest("[role=dialog]") !== null')).to be true
    click_button 'Close modal'
    expect(page).not_to have_css('[role="dialog"]')
    expect(page.evaluate_script('document.activeElement.textContent')).to include('Log Movie')
  end

  it 'supports profile navigation, keyboard auth tabs and failed artwork without retry loops' do
    user = create_and_login_user
    movie = Movie.create!(title: 'Broken artwork', thumbnail_url: 'https://images.example.test/dead.jpg')
    LibraryItem.create!(user: user, item: movie, is_collected: true)
    visit movie_path(movie)
    expect(page).to have_css('img[data-failed="true"]', visible: :hidden)
    expect(page).to have_content('Artwork unavailable')
    visit user_path(user)
    within('.library-profile-tabs') { click_link 'Collection' }
    expect(page).to have_css('.library-profile-tabs a[aria-current="page"]', text: 'Collection')
    expect(page).to have_content('Broken artwork')
    visit login_path
    expect(page).to have_css('[data-controller="tabs"][data-connected="true"]')
    page.find('[role="tab"][data-tab-name="email"]').send_keys(:arrow_right)
    expect(page).to have_css('[role="tab"][data-tab-name="bsky-oauth"][aria-selected="true"]')
  end

  it 'shows refresh results and moves keyboard focus to the opened metadata disclosure' do
    create_and_login_user
    show = TvShow.create!(title: 'Refreshable show')
    show.update_columns(api_id: '42')
    stub_request(:get, 'https://api.tvmaze.com/shows/42').to_return(body: { network: { name: 'A network' } }.to_json)
    stub_request(:get, 'https://api.tvmaze.com/shows/42/episodes').to_return(body: [].to_json)
    visit tv_show_path(show)
    find('#metadata-health summary').click
    click_button 'Refresh metadata'
    expect(page).to have_css('#metadata-health[open][data-refresh-result="true"]')
    expect(page).to have_content('Metadata refreshed. Your library history and reviews are preserved.')
    expect(page.evaluate_script('document.activeElement.closest("#metadata-health") !== null')).to be true
    expect(show.reload.network).to eq('A network')
  end
end
