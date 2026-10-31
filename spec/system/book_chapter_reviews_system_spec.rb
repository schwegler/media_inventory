# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Book editions and track reviews', type: :system do
  it 'creates a manual edition, tracks a pass, reviews a chapter, and follows author navigation' do
    user = create_and_login_user(email: 'chapter-ui@example.com')
    book = Book.create!(title: 'Synthetic edition novel', author: 'Test writer')
    LibraryItem.create!(user: user, item: book, review: 'My work review', rating: 4, is_public: true)
    visit book_path(book)
    find('summary', text: 'Add an edition and manual chapter list').click
    fill_in 'Edition label', with: 'Test ebook edition'
    select 'ebook', from: 'Format'
    fill_in 'Chapter list (one per line)', with: "Prologue\nPart I | 1 | Arrival\nPart II | Epilogue | Home"
    check 'This is the complete list for this edition'
    click_button 'Add edition'
    expect(page).to have_text('Test ebook edition')
    edition_anchor = "edition-#{book.book_editions.sole.id}"
    expect(page).to have_current_path(book_path(book)) { |uri| uri.fragment == edition_anchor }
    click_button 'Start reading/listening'
    expect(page).to have_text('0 of 3 known chapters completed')
    click_button 'Complete Prologue'
    expect(page).to have_button('Undo Prologue', wait: 10)
    expect(page).to have_current_path(book_path(book)) { |uri| uri.fragment == edition_anchor }
    expect(page).to have_text('1 of 3 known chapters completed')
    capture_ui_screenshot('book-edition-progress-desktop')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
    capture_ui_screenshot('book-edition-progress-mobile')
    resize_browser_viewport(1400, 900)
    click_link 'Prologue'
    expect(page).to have_css('h1', text: 'Prologue')
    click_link 'Write a review'
    within '#modal' do
      expect(page).to have_field('Your review')
      fill_in 'Your review', with: 'A memorable opening.'
      select '★★★★', from: 'Your rating'
      check 'Make review public'
      click_button 'Update Review'
    end
    expect(page).to have_text('A memorable opening.')
    expect(page).to have_no_css('#modal [role="dialog"]')
    click_link 'Read full review'
    expect(page).to have_css('h1', text: 'Prologue')
    expect(page).to have_link('This author’s review of Synthetic edition novel')
    capture_ui_screenshot('chapter-review-desktop')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
    capture_ui_screenshot('chapter-review-mobile')
    click_link 'This author’s review of Synthetic edition novel'
    expect(page).to have_css('[aria-label="This author’s child reviews"]', text: 'Prologue')
    expect(page.driver.browser.logs.get(:browser).select do |entry|
      entry.level == 'SEVERE' && !entry.message.include?('favicon')
    end).to be_empty
    expect(user.library_items.find_by(item: book).reload).not_to be_consumed
  end

  it 'reviews an existing multidisc track with missing artwork without replacing track records' do
    user = create_and_login_user(email: 'track-ui@example.com')
    album = Album.create!(title: 'Synthetic multidisc album')
    track = album.album_tracks.create!(title: 'Second disc opening', provider_id: 'synthetic:2:1', disc_number: 2,
                                       track_number: 1)
    LibraryItem.create!(user: user, item: album, rating: 5)
    visit album_path(album)
    click_link 'Second disc opening'
    expect(page).to have_css('h1', text: track.title)
    click_link 'Write a review'
    within '#modal' do
      fill_in 'Your review', with: 'An excellent performance.'
      check 'Make review public'
      click_button 'Update Review'
    end
    expect(page).to have_text('An excellent performance.')
    click_link 'Read full review'
    expect(page).to have_text('No cover available')
    capture_ui_screenshot('track-review-missing-art')
    expect(album.album_tracks.sole.id).to eq(track.id)
    expect(user.library_items.find_by(item: album).rating).to eq('5')
  end
end
