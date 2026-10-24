# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Remembered sign-in browser behavior', type: :system do
  before { skip 'Set RUN_BROWSER_SPECS=1 to run browser coverage' unless ENV['RUN_BROWSER_SPECS'] == '1' }

  it 'shares an ordinary session with a second regular window in the same browser context and exact host' do
    user = create_and_login_user(email: 'window@example.test')
    expect(page.driver.browser.manage.cookie_named('_sample_app_session')[:expires]).to be_nil
    expect(page.driver.browser.manage.all_cookies.map { |cookie| cookie[:name] }).not_to include('remembered_device')
    origin = URI(page.current_url)
    window = open_new_window
    within_window(window) do
      visit "#{origin.scheme}://#{origin.host}:#{origin.port}#{edit_user_path(user)}"
      expect(page).to have_field('Email', with: user.email)
      expect(URI(page.current_url).host).to eq(origin.host)
    end
    window.close
  end

  it 'restores after browser-session cookie loss and preserves accessible mobile controls under reduced motion' do
    user = User.create!(name: 'Restart Member', email: 'restart@example.test', password: 'password123')
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia',
                                    features: [{ name: 'prefers-reduced-motion', value: 'reduce' }])
    [1400, 390].each do |width|
      resize_browser_viewport(width, 900)
      visit login_path
      expect(page).to have_title(/Trove/)
      expect(page).to have_css('h1', text: 'Unlock Your Media Vault')
      checkbox = find('#email_remember_device')
      expect(checkbox).not_to be_checked
      expect(page).to have_css("##{checkbox['aria-describedby']}", text: 'private device')
      check 'email_remember_device'
      expect(checkbox).to be_checked
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
      expect(page.evaluate_script("matchMedia('(prefers-reduced-motion: reduce)').matches")).to be true
      capture_ui_screenshot("remember-device-#{width}")
    end
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
    expect(page).to have_text('Logged in successfully.')
    remembered = page.driver.browser.manage.cookie_named('remembered_device')
    expect(remembered[:expires]).to be > Time.current
    page.driver.browser.manage.delete_cookie('_sample_app_session')
    visit edit_user_path(user)
    expect(page).to have_field('Email', with: user.email)
    expect(page.driver.browser.manage.cookie_named('remembered_device')[:value]).not_to eq(remembered[:value])
  end
  it 'persists opt-in through an actual Chrome exit and relaunch with the same browser profile' do
    Dir.mktmpdir('remembered-browser-') do |profile|
      Capybara.register_driver :remembered_profile do |app|
        options = Selenium::WebDriver::Chrome::Options.new
        options.binary = ENV['SE_CHROME_PATH'] if ENV['SE_CHROME_PATH'].present?
        %w[--headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage].each { |arg| options.add_argument(arg) }
        options.add_argument("--user-data-dir=#{profile}")
        service = Selenium::WebDriver::Chrome::Service.new(path: ENV['SE_CHROMEDRIVER']) if ENV['SE_CHROMEDRIVER'].present?
        Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, service: service)
      end
      driven_by :remembered_profile
      user = User.create!(name: 'Browser Restart', email: 'browser-restart@example.test', password: 'password123')
      visit login_path
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password123'
      check 'email_remember_device'
      click_button 'Log in'
      expect(page).to have_text('Logged in successfully.')
      original = page.driver.browser.manage.cookie_named('remembered_device')[:value]
      # Chrome may restore ordinary session cookies on startup. Remove that cookie
      # before exit so this test specifically proves persisted remember restoration.
      page.driver.browser.manage.delete_cookie('_sample_app_session')
      page.driver.quit
      visit edit_user_path(user)
      expect(page).to have_field('Email', with: user.email)
      expect(page.driver.browser.manage.cookie_named('remembered_device')[:value]).not_to eq(original)
      page.driver.quit
    end
  end
end
