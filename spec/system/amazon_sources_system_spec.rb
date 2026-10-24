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

  it 'keeps original guidance and disclosure visible next to accessible paid links' do
    book = Book.create!(title: 'Dracula', author: 'Bram Stoker')
    [[1440, 1000, 'desktop'], [390, 844, 'mobile']].each do |width, height, size|
      resize_browser_viewport(width, height)
      visit book_path(book)
      expect(page.title).to include('Dracula')
      expect(page).to have_css('#my-library')
      within '.streaming-links-box' do
        expect(page).to have_text('A Halloween reading idea')
        expect(page).to have_text('As an Amazon Associate I earn from qualifying purchases.')
        link = find_link('Search Amazon (paid link)')
        expect(link[:href]).to eq('https://www.amazon.com/s?k=Dracula&tag=schweg-20')
        expect(link[:rel].split).to include('sponsored', 'noopener')
      end
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
      expect(page.evaluate_script("getComputedStyle(document.querySelector('.amazon-disclosure')).fontSize")).to eq('16px')
      page.execute_script("document.querySelector('.amazon-reading').scrollIntoView({block: 'center'})")
      capture_ui_screenshot("amazon-#{size}-guidance")
      page.execute_script("document.querySelector('.amazon-disclosure').scrollIntoView({block: 'center'})")
      capture_ui_screenshot("amazon-#{size}-disclosure")
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
    expect(page).to have_no_text('paid link')
    expect(page).to have_no_css('.amazon-disclosure')
    Rails.configuration.x.amazon_associates_tag = nil
    book.update!(title: 'Dracula', author: 'Bram Stoker')
    visit book_path(book)
    expect(page).to have_link('Search Amazon', href: 'https://www.amazon.com/s?k=Dracula')
    expect(page).to have_no_css('.amazon-disclosure')
  end
end
