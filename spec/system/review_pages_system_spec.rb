# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dedicated review reading and sharing', type: :system do
  let!(:author) { User.create!(name: 'Alex Reader', email: 'review-system@example.com', password: 'password123') }
  let!(:book) do
    Book.create!(title: 'Frankenstein; or, The Modern Prometheus', release_year: 1818).tap do |item|
      item.cover_image.attach(io: File.open(Rails.root.join('spec/fixtures/files/discovery_covers/cover-5.jpg')),
                              filename: 'frankenstein.jpg', content_type: 'image/jpeg')
    end
  end
  let!(:entry) do
    body = "Some stories stay with you.\n\nA thoughtful story about responsibility and belonging. " \
           'The quieter moments made me stop and think: an unfinished conversation, a familiar landscape, ' \
           "the things left unsaid.\n\nWhat I loved:\n\n1. The careful attention to everyday details.\n" \
           "2. Characters who feel like people rather than plot devices.\n" \
           '3. Questions that give you room to find your own meaning.'
    body += "\n\nI would read this again."
    LibraryItem.create!(user: author, item: book, is_public: true, rating: 4.5, consumed: true,
                        consumed_at: Date.new(2026, 10, 20), review: body)
  end

  it 'keeps the full review readable on desktop, mobile, light, dark, and 200 percent reflow' do
    visit public_review_path(entry)
    expect(page).to have_css('.review-page-share[data-connected="true"]')
    click_button 'Dismiss Halloween character' if page.has_button?('Dismiss Halloween character', wait: 3)
    [[1400, 1000, 'dark'], [390, 844, 'light'], [700, 900, 'light']].each do |width, height, theme|
      resize_browser_viewport(width, height)
      page.execute_script("document.documentElement.dataset.theme = '#{theme}'")
      expect(page).to have_text('I would read this again.')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
      capture_ui_screenshot("review-#{width}-#{theme}")
    end
    # A 1400px viewport at 200 percent browser zoom has a 700 CSS-pixel layout.
    resize_browser_viewport(700, 1000)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
    capture_ui_screenshot('review-200-percent')
    book.cover_image.purge
    entry.update!(review: "#{entry.review}\n\n#{'A long paragraph for reflow verification. ' * 80}")
    book.update!(title: "A title with many words and a very long unbroken string #{'LongTitle' * 20}")
    visit public_review_path(entry)
    resize_browser_viewport(320, 900)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
    expect(page).to have_text('I would read this again.')
    capture_ui_screenshot('review-long-title-320')
    resize_browser_viewport(1400, 1000)
    capture_ui_screenshot('review-missing-art-desktop')
  end

  it 'shows bounded community excerpts and follows the full-review link with the keyboard' do
    entry.update!(review: "Opening paragraph with a <a href=\"https://example.com/reading\">reading link</a>.\n\n" \
                          "#{'Thoughtful words 👩🏽‍🚀 about the story. ' * 100}\n\n" \
                          '<a href="https://example.com/omitted">THE FULL ENDING</a>')
    visit "#{book_path(book)}#community"
    click_button 'Dismiss Halloween character' if page.has_button?('Dismiss Halloween character', wait: 3)
    card = find('.show-review-card')
    expect(card).to have_link('reading link', href: 'https://example.com/reading')
    expect(card).to have_no_link('THE FULL ENDING')
    expect(card.text).not_to include('THE FULL ENDING')
    expect(card.find('.review-excerpt-link')['aria-label']).to include(author.name, book.title)
    [1400, 390].each do |width|
      resize_browser_viewport(width, 900)
      card.scroll_to(:top)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
      expect(card.find('.review-excerpt').native.size.height).to be < 600
      capture_ui_screenshot("review-excerpt-#{width}")
    end
    card.find_link('Read full review').send_keys(:enter)
    expect(page).to have_current_path(public_review_path(entry))
    expect(page).to have_link('THE FULL ENDING', href: 'https://example.com/omitted')
  end

  it 'bounds a Madonna album review and gives short general-feed events an obvious review link' do
    album = Album.create!(title: 'CONFESSIONS II', artist: 'Madonna', release_year: 2026)
    body = (1..12).map { |number| "Paragraph #{number}. #{'A synthetic album listening note. ' * 25}" }.join("\n\n")
    album_entry = LibraryItem.create!(user: author, item: album, is_public: true, review: body, rating: 4.5)
    visit "#{album_path(album)}#community"
    click_button 'Dismiss Halloween character' if page.has_button?('Dismiss Halloween character', wait: 3)
    card = find('.show-review-card')
    expect(card.text).not_to include('Paragraph 12.')
    [1400, 390].each do |width|
      resize_browser_viewport(width, 900)
      card.scroll_to(:top)
      expect(card.find('.review-excerpt').native.size.height).to be < 600
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
      capture_ui_screenshot("madonna-review-excerpt-#{width}")
    end
    card.find_link('Read full review').send_keys(:enter)
    expect(page).to have_current_path(public_review_path(album_entry))
    expect(page).to have_text('Paragraph 12.')
    album_entry.update!(review: 'A short album review.')
    visit root_path
    find('summary', text: 'From the community').click
    event = all('.activity-card').find { |node| node.has_text?(album.title) }
    expect(event).to have_link('View review', href: public_review_path(album_entry))
    expect(event).to have_text('A short album review.')
    event.scroll_to(:top)
    capture_ui_screenshot('review-short-event-mobile')
    event.find_link('View review').send_keys(:enter)
    expect(page).to have_current_path(public_review_path(album_entry))
  end

  it 'copies the review permalink, offers native sharing, and restores focus after fallback Escape' do
    visit public_review_path(entry)
    expect(page).to have_css('.review-page-share[data-connected="true"]')
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'clipboard', {configurable: true, value: {writeText: async url => {window.copiedReview = url}}});
    JS
    find_button('Copy review link').send_keys(:enter)
    expect(page).to have_text('Link copied.')
    expect(page.evaluate_script('window.copiedReview')).to end_with(public_review_path(entry))
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'clipboard', {configurable: true, value: undefined});
    JS
    click_button 'Copy review link'
    fallback = find('input[aria-label="Public review link"]')
    expect(page.evaluate_script('document.activeElement.getAttribute("aria-label")')).to eq('Public review link')
    fallback.send_keys(:escape)
    expect(page).to have_no_css('input[aria-label="Public review link"]')
    expect(page.evaluate_script('document.activeElement.textContent')).to eq('Copy review link')
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'share', {configurable: true, value: async data => {window.sharedReview = data}});
    JS
    visit public_review_path(entry)
    # Navigator mocks survive same-document Turbo navigation.
    expect(page).to have_css('.review-page-share[data-connected="true"]')
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'share', {configurable: true, value: async data => {window.sharedReview = data}});
      document.querySelector('[data-link-share-target="native"]').hidden = false;
    JS
    click_button 'Share review…'
    expect(page).to have_text('Shared.')
    expect(page.evaluate_script('window.sharedReview.url')).to end_with(public_review_path(entry))
  end
end
