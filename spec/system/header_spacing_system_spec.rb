# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Header spacing', type: :system do
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
