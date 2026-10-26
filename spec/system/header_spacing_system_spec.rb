# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Header spacing', type: :system do
  def expect_search_anchored
    page.document.synchronize(5, errors: [RSpec::Expectations::ExpectationNotMetError]) do
      bounds = page.evaluate_script(<<~JS)
        (() => {
          const button = document.querySelector('.combined-search-toggle').getBoundingClientRect();
          const panel = document.querySelector('#header-search-panel').getBoundingClientRect();
          return { left: panel.left, right: panel.right, gap: panel.top - button.bottom,
            expectedRight: Math.max(12 + panel.width, Math.min(button.right, document.documentElement.clientWidth - 12)),
            viewport: document.documentElement.clientWidth, overflow: document.documentElement.scrollWidth > innerWidth };
        })()
      JS
      expect(bounds['right']).to be_within(1).of(bounds['expectedRight'])
      expect(bounds['gap']).to be_within(1).of(8)
      expect(bounds['left']).to be >= 11
      expect(bounds['right']).to be <= bounds['viewport'] - 11
      expect(bounds['overflow']).to be false
    end
  end

  it 'anchors search to its button across desktop, floating, narrow and zoomed layouts' do
    create_and_login_user
    visit movies_path
    expect(page).to have_css('[data-controller~="header-search"][data-connected="true"]')
    page.driver.browser.logs.get(:browser)
    resize_browser_viewport(2048, 1155)
    %w[light dark].each do |theme|
      page.execute_script('document.documentElement.dataset.theme = arguments[0]', theme)
      click_button 'Search Trove and supported catalogs'
      expect_search_anchored
      expect(page).to have_css('#header-search-panel input:focus')
      capture_ui_screenshot("search-anchored-2048-#{theme}")
      find('#header-search-panel input').send_keys(:escape)
      expect(page).to have_css('.combined-search-toggle:focus[aria-expanded="false"]')
    end

    click_button 'Search Trove and supported catalogs'
    fill_in 'Search Trove and supported catalogs', with: 'Dune'
    resize_browser_viewport(1100, 900)
    expect_search_anchored
    # Force a scrollable page even when the test catalog has no movies.
    page.execute_script('document.body.style.minHeight = "2400px"; window.scrollTo(0, 400)')
    expect(page).to have_css('.combined-header.search-open')
    expect_search_anchored
    capture_ui_screenshot('search-anchored-floating')
    page.execute_script('window.scrollTo(0, 0)')
    expect(page).not_to have_css('.combined-header')
    expect_search_anchored

    # 1440px desktop at 200% zoom exposes a 720px CSS viewport.
    resize_browser_viewport(720, 450)
    expect(page).not_to have_css('.app-header.search-open')
    expect(page).to have_css('#header-search-panel input:focus')
    expect(page).to have_field('Search Trove and supported catalogs', with: 'Dune')
    capture_ui_screenshot('search-inline-200-percent-reflow')
    resize_browser_viewport(390, 844)
    expect(page).to have_field('Search Trove and supported catalogs', with: 'Dune')
    expect(page.evaluate_script('document.documentElement.scrollWidth')).to be <= 390
    capture_ui_screenshot('search-inline-390')
    resize_browser_viewport(320, 700)
    click_button 'Search Trove and supported catalogs'
    expect_search_anchored
    capture_ui_screenshot('search-anchored-320')
    find('label', text: 'Search movies').click
    expect(page).to have_css('.combined-search-toggle[aria-expanded="false"]')
    find('.combined-search-toggle').send_keys(:enter)
    expect_search_anchored
    expect(page).to have_css('#header-search-panel input:focus')
    find('#header-search-panel input').send_keys(:escape)
    expect(page).to have_css('.combined-search-toggle:focus')
    errors = page.driver.browser.logs.get(:browser).select do |entry|
      entry.level == 'SEVERE' && !entry.message.include?('Content Security Policy')
    end
    expect(errors.map(&:message)).to be_empty
  end

  it 'keeps the credit beside the wordmark without enlarging desktop or responsive headers' do
    # Selenium retains console entries from earlier examples in the same browser.
    page.driver.browser.logs.get(:browser)
    create_and_login_user
    visit movies_path
    expect(page).to have_current_path(movies_path)
    expect(page).to have_css('h1', text: 'Movies')
    expect(page).to have_css('[data-controller="floating-header"][data-connected="true"]')

    [1440, 1100, 768, 390, 320].each do |width|
      resize_browser_viewport(width, 900)
      page.execute_script('window.scrollTo(0, 0)')
      expect(page).not_to have_css('.combined-header')
      capture_ui_screenshot("header-#{width}")
      metrics = page.evaluate_script(<<~JS)
        (() => {
          const rect = selector => document.querySelector(selector).getBoundingClientRect();
          const header = rect('.app-header'), brand = rect('.brand-link'), credit = rect('.brand-companion');
          return { height: header.height, brandTop: brand.top, brandBottom: brand.bottom,
            creditTop: credit.top, creditBottom: credit.bottom, creditHeight: credit.height,
            overflow: document.documentElement.scrollWidth > innerWidth };
        })()
      JS
      # Allow the border and fractional font metrics across Chrome versions.
      expect(metrics['height']).to be <= (width > 720 ? 78 : 70)
      expect(metrics['overflow']).to be false
      expect(page.evaluate_script(<<~JS)).to be true
        (() => {
          const items = [...document.querySelector('.app-nav').children]
            .filter(el => getComputedStyle(el).position !== 'absolute' && el.getClientRects().length)
            .map(el => el.getBoundingClientRect());
          return items.every((rect, i) => i === 0 || rect.left >= items[i - 1].right - 1);
        })()
      JS
      if width >= 1400
        expect(page).to have_link('from taco ’bout it', href: 'https://tacobout.online/', visible: true)
        expect(metrics['creditHeight']).to be >= 44
        expect(metrics['creditTop']).to be <= metrics['brandTop']
        expect(metrics['creditBottom']).to be >= metrics['brandBottom']
        find('.brand-link').send_keys(:tab)
        expect(page).to have_css('.brand-companion:focus')
      else
        expect(page).to have_no_css('.brand-companion', visible: true)
      end
      next if width >= 1100

      click_button 'Toggle navigation'
      expect(page).to have_link('Blog — taco ’bout it', href: 'https://tacobout.online/', visible: true)
      panel = page.evaluate_script('document.querySelector(".mobile-nav-panel").getBoundingClientRect().toJSON()')
      expect(panel['left']).to be >= 0
      expect(panel['right']).to be <= width
      capture_ui_screenshot("header-menu-#{width}")
      find('.mobile-menu-btn').send_keys(:escape)
      expect(page).to have_css('.mobile-menu-btn:focus[aria-expanded="false"]')
    end

    resize_browser_viewport(1440, 900)
    page.execute_script('window.scrollTo(0, 400)')
    expect(page).to have_css('.combined-header')
    expect(page.evaluate_script('document.querySelector(".app-header").getBoundingClientRect().bottom')).to be <= 90
    capture_ui_screenshot('header-sticky')
    # The app's existing analytics CSP reports are unrelated to header interactions.
    errors = page.driver.browser.logs.get(:browser).select do |entry|
      entry.level == 'SEVERE' && !entry.message.include?('Content Security Policy')
    end
    expect(errors.map(&:message)).to be_empty
  end

  it 'reflows at the effective viewport of a desktop browser zoomed to 200 percent' do
    create_and_login_user
    visit movies_path
    # 1440x900 at 200% browser zoom exposes a 720x450 CSS-pixel viewport.
    resize_browser_viewport(720, 450)
    expect(page).to have_css('.mobile-menu-btn', visible: true)
    expect(page.evaluate_script('document.documentElement.scrollWidth')).to be <= 720
    click_button 'Toggle navigation'
    credit = find_link('Blog — taco ’bout it')
    expect(credit.evaluate_script('this.getBoundingClientRect().height')).to be >= 44
    capture_ui_screenshot('header-200-percent-reflow')
    find('.mobile-menu-btn').send_keys(:escape)
    expect(page).to have_css('.mobile-menu-btn:focus')
  end
end
