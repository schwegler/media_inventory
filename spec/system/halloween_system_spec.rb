# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Halloween invitation', type: :system do
  include ActiveSupport::Testing::TimeHelpers

  around { |example| travel_to(Time.utc(2026, 10, 20, 12)) { example.run } }

  before do
    page.driver.browser.execute_cdp('Page.addScriptToEvaluateOnNewDocument',
                                    source: 'Date.now = () => Date.UTC(2026, 9, 20, 12)')
  end

  it 'requires activation, offers keyboard Undo, and preserves the original appearance' do
    create_and_login_user
    visit root_path
    expect(page).to have_button('Try the Halloween theme')
    expect(page).to have_css('html[data-theme="os"][data-accent="violet"]')
    find('[aria-label="Try the Halloween theme"]').send_keys(:enter)
    expect(page).to have_css('html[data-theme="dark"][data-accent="halloween"]')
    expect(page).to have_css('[role="alert"]', text: 'Halloween appearance applied')
    expect(page).to have_css('button:focus', text: 'Undo')
    capture_ui_screenshot('halloween-desktop')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    capture_ui_screenshot('halloween-mobile')
    find('button', text: 'Undo', exact_text: true).send_keys(:enter)
    expect(page).to have_css('html[data-theme="os"][data-accent="violet"]')
    visit root_path
    expect(page).not_to have_button('Try the Halloween theme')
  end
end
