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
      page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride')
      page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [])
      page.current_window.resize_to(1400, 900)
      if ENV.fetch('UI_QA_DIR', nil)
        @browser_failure_trace_browser = page.driver.browser
        @browser_failure_trace_id = BrowserInputTrace.install(@browser_failure_trace_browser)
      end
    end
  end

  config.after(:each, type: :system) do |example|
    next unless example.exception && ENV.fetch('UI_QA_DIR', nil) && ENV['ANTIGRAVITY_AGENT'] != '1'

    directory = File.join(ENV.fetch('UI_QA_DIR'), 'failures', example.id.gsub(/[^a-zA-Z0-9_-]/, '_'))
    FileUtils.mkdir_p(directory)
    page.driver.browser.save_screenshot(File.join(directory, 'page.png'))
    File.write(File.join(directory, 'page.html'), page.html)
    state = page.evaluate_script(<<~JS)
      ({ url: location.href, referrer: document.referrer, viewport: [innerWidth, innerHeight],
         focused: document.hasFocus(), visibility: document.visibilityState, readyState: document.readyState,
         inputEvents: window.troveBrowserFailureEvents || [],
         reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches,
         activeElement: document.activeElement?.outerHTML,
         controllers: (window.Stimulus?.controllers || []).map(controller => ({
           identifier: controller.identifier, connected: controller.element.isConnected,
           state: Object.fromEntries(['searchStageActive', 'currentQuery', 'version', 'presentationSaving',
             'presentationDirty', 'picksSaving', 'imageStyle', 'imageTheme'].filter(key => controller[key] !== undefined)
             .map(key => [key, controller[key]]))
         })),
         resources: performance.getEntriesByType('resource').slice(-30).map(entry => ({
           name: entry.name, duration: entry.duration, responseEnd: entry.responseEnd, type: entry.initiatorType
         })) })
    JS
    File.write(File.join(directory, 'state.json'), JSON.pretty_generate(state))
    File.write(File.join(directory, 'browser.log'), page.driver.browser.logs.get(:browser).join("\n"))
  rescue StandardError => e
    warn "Browser failure diagnostics could not be saved: #{e.class}: #{e.message}"
  ensure
    BrowserInputTrace.remove(@browser_failure_trace_browser, @browser_failure_trace_id)
  end
end

# Shared helper methods for system specs
module SystemTestHelpers
  def resize_browser_viewport(width, height)
    page.current_window.resize_to(width, height)
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride',
                                    width: width, height: height, deviceScaleFactor: 1, mobile: false)
    expect(page.evaluate_script('window.innerWidth')).to eq(width)
  end

  def capture_ui_screenshot(name)
    return unless ENV['UI_QA_DIR']

    FileUtils.mkdir_p(ENV.fetch('UI_QA_DIR'))
    page.driver.browser.save_screenshot(File.join(ENV.fetch('UI_QA_DIR'), "#{name}.png"))
  end

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
      expect(page).to have_css('[data-connected="true"]')
      # Force a blur to ensure input events have fired and state is synchronized
      page.execute_script('document.activeElement.blur()')

      # Wait for thumbnail search to fully settle to prevent any DOM shifts or
      # background requests from clearing the form
      sleep 1.5

      selector = "button[data-action='click->thumbnail-fetcher#showManualForm']"
      page.execute_script("document.querySelector(#{selector.inspect}).click()")
    end
  end
end

RSpec.configure do |config|
  config.include SystemTestHelpers, type: :system
end
