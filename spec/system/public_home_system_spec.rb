# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Cover-led public homepage', type: :system do
  include PublicHomeFixture

  before do
    page.driver.browser.logs.get(:browser)
    build_public_home_fixture
  end

  it 'demonstrates real covers and public shelves with one search focal point at desktop and phone sizes' do
    visit root_path
    expect(page).to have_css('.home-cover', count: 6)
    expect(page).to have_css('.home-shelf-example', count: 2)
    expect(page).to have_css('input[type="search"]', visible: true, count: 1)
    expect(page).not_to have_text('Coverage varies')
    expect(page).not_to have_text('Community Activity')
    expect(page).to have_text('Riley (QA fixture)')
    expect(page).to have_text('Morgan (QA fixture)')
    expect(page).not_to have_text('Make it yours')
    expect(page).not_to have_css('.home-blog')
    page.all('.home-cover img').each { |image| expect(image['naturalWidth'].to_i).to be_positive }
    [1440, 390, 360, 768].each do |width|
      resize_browser_viewport(width, 1000)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
      expect(page).to have_css('input[type="search"]', visible: true, count: 1)
      expect(find_button('Search').rect.height).to be >= 44
      capture_ui_screenshot("public-home-refined-#{width}")
    end
    resize_browser_viewport(1440, 1000)
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride',
                                    width: 720, height: 500, deviceScaleFactor: 2, mobile: false)
    expect(page.evaluate_script('window.innerWidth')).to eq(720)
    expect(page.evaluate_script('window.devicePixelRatio')).to eq(2)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    capture_ui_screenshot('public-home-refined-zoom-200')
    resize_browser_viewport(1440, 1000)
    find('summary[aria-label="Appearance"]').click
    within('.appearance-panel') { choose 'Dark' }
    find('summary[aria-label="Appearance"]').send_keys(:escape)
    expect(page).to have_css('.home-actions a', style: { color: /239,\s*237,\s*244/ })
    capture_ui_screenshot('public-home-refined-dark')
    find('summary[aria-label="Appearance"]').click
    within('.appearance-panel') { choose 'System' }
    find('summary[aria-label="Appearance"]').send_keys(:escape)
    expect(page.driver.browser.logs.get(:browser).select { |entry| entry.level == 'SEVERE' }).to be_empty
    expect(LibraryItem.count).to eq(0)
  end

  it 'reveals catalog coverage on demand, keeps search usable and opens actual catalog titles with the keyboard' do
    visit root_path
    fill_in 'Find something you love', with: 'Madonna'
    find('summary', text: 'About the catalog').click
    expect(page).to have_text('In Trove', exact: false)
    expect(page).to have_text('Available to import')
    expect(page).to have_text('Music discovery searches albums')
    expect(page).to have_field('Find something you love', with: 'Madonna')
    find('summary', text: 'About the catalog').click
    click_button 'Search'
    expect(page).to have_field('Search media', with: 'Madonna')
    expect(page).to have_link('Search music (albums)')
    page.go_back
    expect(page).to have_css('.home-cover', count: 6)
    first = find('.home-cover', match: :first)
    title = first['aria-label'].delete_suffix(' — in Trove')
    first.send_keys(:enter)
    expect(page).to have_css('h1', text: title)
    expect(LibraryItem.count).to eq(0)
  end
end
