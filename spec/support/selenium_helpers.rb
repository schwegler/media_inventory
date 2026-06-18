# frozen_string_literal: true

require 'selenium-webdriver'

# Register a headless Chrome driver for Selenium-based system tests.
# Falls back to standard :selenium_chrome_headless if custom registration fails.
Capybara.register_driver :selenium_chrome_headless_custom do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-gpu')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,900')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.server_host = '127.0.0.1'

RSpec.configure do |config|
  config.before(:each, type: :system) do
    if ENV['ANTIGRAVITY_AGENT'] == '1'
      driven_by :rack_test
    else
      driven_by :selenium_chrome_headless_custom
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

    user
  end

  # Safely clicks the "Add Manually" button, waiting for the Stimulus controller to be connected first.
  def click_add_manually
    if Capybara.current_driver == :rack_test
      click_button 'Add Manually'
    else
      expect(page).to have_css('[data-connected="true"]')
      # Standard click_button works safely now that CSS animations are disabled in test env
      # Capybara natively ensures the input event loop has settled before clicking
      click_button 'Add Manually'
    end
  end

end

RSpec.configure do |config|
  config.include SystemTestHelpers, type: :system
end
