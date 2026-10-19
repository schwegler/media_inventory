# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Halloween invitation', type: :system do
  include ActiveSupport::Testing::TimeHelpers

  around { |example| travel_to(Time.utc(2026, 10, 20, 12)) { example.run } }

  before do
    clock = page.driver.browser.execute_cdp('Page.addScriptToEvaluateOnNewDocument',
                                            source: 'Date.now = () => Date.UTC(2026, 9, 20, 12)')
    @clock_script_id = clock.fetch('identifier')
  end

  after do
    page.driver.browser.execute_cdp('Page.removeScriptToEvaluateOnNewDocument', identifier: @clock_script_id)
  end

  it 'requires activation, offers keyboard Undo, and preserves the original appearance' do
    create_and_login_user
    visit root_path
    expect(page).to have_button('Turn on Halloween mode')
    expect(page).to have_css('html[data-theme="os"][data-accent="violet"]')
    find('[aria-label="Turn on Halloween mode"]').send_keys(:enter)
    expect(page).to have_css('html[data-theme="dark"][data-accent="halloween"]')
    expect(page).to have_css('[role="alert"]', text: 'well. it’s haunted now.', visible: :all)
    expect(page).to have_css('details.appearance-menu > summary:focus')
    visit movies_path
    expect(page).to have_css('html[data-theme="dark"][data-accent="halloween"]')
    find('summary[aria-label="Appearance"]').click unless page.has_css?('details.appearance-menu[open]')
    click_button 'Undo Halloween'
    expect(page).to have_css('html[data-theme="os"][data-accent="violet"]')
    page.execute_script(<<~JS)
      localStorage.removeItem('seasonal-theme:v1');
      sessionStorage.removeItem('seasonal-prompt:v1:halloween-2026');
    JS
    visit root_path
    click_button 'Turn on Halloween mode'
    capture_ui_screenshot('halloween-desktop')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    capture_ui_screenshot('halloween-mobile')
    find('summary[aria-label="Appearance"]').click
    find('button', text: 'Undo Halloween', exact_text: true).send_keys(:enter)
    expect(page).to have_css('html[data-theme="os"][data-accent="violet"]')
    visit root_path
    expect(page).not_to have_button('Turn on Halloween mode')
  end

  it 'dismisses only the mascot and consolidates persistent controls in Appearance on mobile' do
    create_and_login_user
    visit root_path
    click_button 'Turn on Halloween mode'
    expect(page).to have_no_css('details.appearance-menu[open]')
    expect(page).to have_no_css('.seasonal-notice', visible: true)
    click_button 'Dismiss Halloween character'
    expect(page).to have_css('html[data-season="halloween"]')
    expect(page).to have_no_css('.halloween-invitation', visible: true)
    expect(page).to have_no_css('.seasonal-notice', visible: true)
    visit movies_path
    expect(page).to have_css('html[data-season="halloween"]')
    resize_browser_viewport(390, 844)
    appearance = find('summary[aria-label="Appearance"]')
    appearance.send_keys(:enter)
    click_button 'Pause motion'
    expect(page).to have_css('html[data-season-motion="paused"]')
    expect(page.evaluate_script('getComputedStyle(document.querySelector(".seasonal-mist")).animationName')).to eq('none')
    click_button 'Hide atmosphere'
    expect(page).to have_css('html[data-season-effects="off"]')
    expect(page.evaluate_script('getComputedStyle(document.querySelector(".seasonal-scene")).display')).to eq('none')
    capture_ui_screenshot('appearance-menu-mobile')
    click_button 'Restore Halloween character'
    expect(page).to have_css('html[data-season="halloween"]')
    expect(page).to have_css('button[aria-label="Open Halloween appearance controls"]', visible: :all)
    choose 'Light'
    expect(page).to have_css('html[data-theme="light"]')
    expect(page).not_to have_css('html[data-season]')
    appearance.send_keys(:escape)
    expect(appearance).to match_css(':focus')
    visit root_path
    expect(page).to have_css('html[data-theme="light"]')
  end
  it 'saves Halloween night from settings and shares that state with the header without an invitation' do
    user = create_and_login_user
    user.update!(username: 'saved_halloween')
    visit settings_appearance_path
    choose 'Halloween night'
    find('input[value="Save preferences"]').send_keys(:enter)
    expect(page).to have_text('Appearance preferences saved.')
    expect(page).to have_css('html[data-theme="dark"][data-season="halloween"]')
    expect(user.reload.seasonal_theme).to eq('halloween')
    expect(user.theme).to eq('os')
    expect(page).to have_checked_field('Halloween night')
    expect(page).to have_no_button('Turn on Halloween mode')
    page.execute_script('window.scrollTo(0, 0)')
    capture_ui_screenshot('saved-halloween-settings-desktop')
    visit shelf_path(user.username, category: 'Movie', theme: 'electric')
    find('summary[aria-label="Appearance"]').click
    expect(page).to have_css('button[aria-pressed="true"]', text: 'Halloween night')
    click_button 'Off'
    expect(page).to have_css(%(body[data-ui-preferences*='"seasonalTheme":"off"']))
    expect(user.reload.seasonal_theme).to eq('off')
    expect(page).to have_css('.favorite-shelf[data-shelf-theme="electric"]')
    find('summary[aria-label="Appearance"]').click
    click_button 'Halloween night'
    expect(page).to have_css(%(body[data-ui-preferences*='"seasonalTheme":"halloween"']))
    expect(user.reload.seasonal_theme).to eq('halloween')
    visit settings_appearance_path
    expect(page).to have_checked_field('Halloween night')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
    page.execute_script(<<~JS)
      document.querySelector("#user_seasonal_theme_halloween").closest("fieldset").scrollIntoView({block: "center"})
    JS
    capture_ui_screenshot('saved-halloween-settings-mobile')
  end
end
