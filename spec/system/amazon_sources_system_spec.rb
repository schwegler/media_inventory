# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Amazon title searches', type: :system do
  around do |example|
    previous = Rails.configuration.x.amazon_associates_tag
    Rails.configuration.x.amazon_associates_tag = 'schweg-20'
    example.run
  ensure
    Rails.configuration.x.amazon_associates_tag = previous
  end

  before do
    # Earlier security examples deliberately trigger CSP violations in this browser.
    page.driver.browser.navigate.to('about:blank')
    page.driver.browser.logs.get(:browser)
  end

  it 'keeps paid labels near links and puts original guidance and disclosure in their own reading areas' do
    book = Book.create!(title: 'Dracula', author: 'Bram Stoker')
    [[1440, 1000, 'desktop'], [390, 844, 'mobile']].each do |width, height, size|
      resize_browser_viewport(width, height)
      visit book_path(book)
      expect(page.title).to include('Dracula')
      expect(page).to have_css('#my-library')
      within '.streaming-links-box' do
        expect(page).to have_no_css('.amazon-reading, .amazon-disclosure')
        link = find_link('Search Amazon (paid link)')
        expect(link[:href]).to eq('https://www.amazon.com/s?k=Dracula&tag=schweg-20')
        expect(link[:rel].split).to include('sponsored', 'noopener')
      end
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
      expect(page).to have_css('.media-detail-main > .amazon-reading h2', text: 'A Halloween reading idea')
      expect(page).to have_css('.app-footer .footer-affiliate-disclosure', count: 1,
                                                                           text: 'As an Amazon Associate I earn from qualifying purchases.')
      expect(page).to have_css('.footer-affiliate-disclosure', count: 1)
      expect(page.evaluate_script("getComputedStyle(document.querySelector('.footer-affiliate-disclosure')).fontSize"))
        .to eq('14px')
      page.execute_script("document.querySelector('.amazon-reading').scrollIntoView({block: 'center'})")
      capture_ui_screenshot("amazon-#{size}-guidance")
      page.execute_script("document.querySelector('.footer-affiliate-disclosure').scrollIntoView({block: 'center'})")
      capture_ui_screenshot("amazon-#{size}-footer")
      page.execute_script("document.querySelector('.streaming-links-box').scrollIntoView({block: 'center'})")
      capture_ui_screenshot("amazon-#{size}-sources")
      find_link('Search Amazon (paid link)').send_keys(:tab)
      page.driver.browser.action.key_down(:shift).send_keys(:tab).key_up(:shift).perform
      expect(page.evaluate_script('document.activeElement.textContent')).to include('Search Amazon (paid link)')
      expect(page.driver.browser.logs.get(:browser).select { |log| log.level == 'SEVERE' }).to be_empty
      find('.media-section-nav a[href="#my-library"]').click
      expect(page).to have_css('#my-library')
    end
  end

  it 'leaves metadata-only titles and disabled configuration unmonetized' do
    book = Book.create!(title: 'Unreviewed Halloween Book', author: 'Unknown')
    visit book_path(book)
    expect(page).to have_link('Search Amazon', href: 'https://www.amazon.com/s?k=Unreviewed+Halloween+Book')
    expect(page).to have_no_link('Search Amazon (paid link)')
    expect(page).to have_css('.app-footer .footer-affiliate-disclosure', count: 1)
    Rails.configuration.x.amazon_associates_tag = nil
    book.update!(title: 'Dracula', author: 'Bram Stoker')
    visit book_path(book)
    expect(page).to have_link('Search Amazon', href: 'https://www.amazon.com/s?k=Dracula')
    expect(page).to have_css('.app-footer .footer-affiliate-disclosure', count: 1)
  end
  it 'shows the general disclosure on pages without affiliate searches in light and dark themes' do
    [[1440, 1000, 'desktop'], [390, 844, 'mobile']].each do |width, height, size|
      resize_browser_viewport(width, height)
      visit root_path
      expect(page).to have_css('.app-footer .footer-affiliate-disclosure', count: 1)
      expect(page).to have_no_link('Search Amazon (paid link)')
      page.execute_script("document.querySelector('.footer-affiliate-disclosure').scrollIntoView({block: 'center'})")
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
      capture_ui_screenshot("affiliate-footer-#{size}-home")
      page.execute_script("document.documentElement.dataset.theme = 'dark'")
      capture_ui_screenshot("affiliate-footer-#{size}-dark")
    end
  end
end
