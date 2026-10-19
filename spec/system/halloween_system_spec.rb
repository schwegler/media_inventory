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
    expect(page).to have_css('[role="alert"]', text: 'well. it’s haunted now.')
    expect(page).to have_css('button:focus', text: 'Undo')
    visit movies_path
    expect(page).to have_css('html[data-theme="dark"][data-accent="halloween"]')
    click_button 'Undo'
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
    find('button', text: 'Undo', exact_text: true).send_keys(:enter)
    expect(page).to have_css('html[data-theme="os"][data-accent="violet"]')
    visit root_path
    expect(page).not_to have_button('Turn on Halloween mode')
  end
end
