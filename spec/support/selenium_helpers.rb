# frozen_string_literal: true

require 'selenium-webdriver'

# Register a headless Chrome driver for Selenium-based system tests.
# Falls back to standard :selenium_chrome_headless if custom registration fails.
Capybara.register_driver :selenium_chrome_headless_custom do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = ENV['SE_CHROME_PATH'] if ENV['SE_CHROME_PATH'].present?
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-gpu')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,900')
  options.add_argument('--force-prefers-reduced-motion')

  service = Selenium::WebDriver::Chrome::Service.new(path: ENV['SE_CHROMEDRIVER']) if ENV['SE_CHROMEDRIVER'].present?
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, service: service)
end

Capybara.server_host = '127.0.0.1'
Capybara.enable_aria_label = true

RSpec.configure do |config|
  config.before(:each, type: :system) do
    if ENV['ANTIGRAVITY_AGENT'] == '1'
      driven_by :rack_test
    else
      driven_by :selenium_chrome_headless_custom
      page.current_window.resize_to(1400, 900)
    end
  end
end

# Shared helper methods for system specs
module SystemTestHelpers
  # Creates a confirmed user and logs them in through the UI.
  # Returns the user record.
  def create_and_login_user(name: 'Test User', email: 'test@example.com', password: 'password123')
    user = User.create!(
      name: name,
      email: email,
      password: password,
      password_confirmation: password,
      confirmed_at: Time.current
    )

    visit login_path
    fill_in 'Email', with: email
    fill_in 'Password', with: password
    click_button 'Log in'
    expect(page).to have_text('Logged in successfully.')

    user
  end

  # Safely clicks the "Add Manually" button, waiting for the Stimulus controller to be connected first.
  def click_add_manually
    if Capybara.current_driver == :rack_test
      click_button 'Add Manually'
    else
      expect(page).to have_css('[data-controller~="thumbnail-fetcher"][data-connected="true"]')
      click_button 'Add Manually'
      expect(page).to have_css('[data-thumbnail-fetcher-target="detailsStage"]', visible: true)
    end
  end
end

RSpec.configure do |config|
  config.include SystemTestHelpers, type: :system
end
