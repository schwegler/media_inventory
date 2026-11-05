# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Media search submission', type: :system do
  before { create_and_login_user(email: 'search-enter@example.com') }

  it 'treats Enter as search across all staged media forms without creating records' do
    [Movie, Album, Book, Comic, TvShow, VideoGame].each do |model|
      initial_count = model.count
      visit new_polymorphic_path(model)
      expect(page).to have_css('[data-connected="true"]')
      fill_in 'Title', with: "Unmatched #{model.name} search"
      find_field('Title').send_keys(:enter)

      expect(page).to have_text(/No (covers|matches|matching series) found/)
      expect(page).to have_current_path(new_polymorphic_path(model))
      expect(page).to have_button('Add Manually')
      expect(model.count).to eq(initial_count)
      expect(LibraryItem.count).to eq(0)
    end
  end

  it 'shows the specific game and explains provider failures in the logging form' do
    stub_request(:get, /storesearch/).to_return(status: 503)
    titles = ["Marvel's Spider-Man", "Marvel's Spider-Man 2", "Marvel's Spider-Man (video game)",
              "Marvel's Spider-Man: Miles Morales"]
    pages = titles.each_with_index.to_h do |title, index|
      [index.to_s, { title: title, pageid: index + 1, index: index + 1,
                     thumbnail: { source: "https://upload.wikimedia.org/cover-#{index}.jpg" } }]
    end
    stub_request(:get, /en.wikipedia.org/).with(query: hash_including('gsrlimit' => '10')).to_return(
      body: { query: { pages: pages } }.to_json
    )
    allow(GameSearchArtwork).to receive(:call) do |results|
      results.map { |result| result.merge(thumbnail_url: nil, artwork_status: 'missing') }
    end

    visit new_video_game_path
    expect(page).to have_css('[data-connected="true"]')
    fill_in 'Title', with: 'spider-man miles'
    find_field('Title').send_keys(:enter)
    expect(page).to have_css('.thumbnail-option-card', count: 4)
    expect(all('.thumbnail-option-card').first).to have_text("Marvel's Spider-Man: Miles Morales")
    expect(page).to have_text('Steam is temporarily unavailable.')
    expect(page).to have_text('RAWG is not configured.')
    expect(page).not_to have_text('Year unknown · unknown')
    expect(VideoGame.count).to eq(0)
    expect(LibraryItem.count).to eq(0)
  end

  it 'guards form submissions and year-field Enter, but allows deliberate manual creation' do
    visit new_comic_path
    expect(page).to have_css('[data-connected="true"]')
    fill_in 'Title', with: 'A deliberate manual comic'
    fill_in 'Series start year (optional)', with: '2024'
    find_field('Series start year (optional)').send_keys(:enter)
    expect(page).to have_text('No matching series found')

    page.execute_script('document.querySelector("form.standard-form").requestSubmit()')
    expect(page).to have_text('No matching series found')
    expect(Comic.count).to eq(0)
    expect(LibraryItem.count).to eq(0)

    click_button 'Add Manually'
    expect(page).to have_text('Log Details')
    click_button 'Create Comic'
    expect(page).to have_text('Comic was successfully logged.')
    expect(Comic.find_by!(title: 'A deliberate manual comic')).to be_present
    expect(LibraryItem.count).to eq(1)
  end

  it 'keeps keyboard result selection working and restores the guard when going back to search' do
    book = Book.create!(title: 'A selectable book')
    visit new_book_path
    expect(page).to have_css('[data-connected="true"]')
    fill_in 'Title', with: 'A selectable book'
    find_field('Title').send_keys(:enter)
    expect(page).to have_css('.thumbnail-option-card', text: book.title)
    find('.thumbnail-option-card', text: book.title).send_keys(:enter)
    expect(page).to have_text('Log Details')
    expect(LibraryItem.count).to eq(0)

    click_button '← BACK'
    expect(page).to have_button('Add Manually')
    find_field('Title').send_keys(:enter)
    expect(page).to have_css('.thumbnail-option-card', text: book.title)
    expect(LibraryItem.count).to eq(0)

    find('.thumbnail-option-card', text: book.title).click
    click_button 'Confirm and save'
    expect(page).to have_text('Book was successfully logged.')
    expect(LibraryItem.last.item).to eq(book)
    expect(Book.count).to eq(1)
  end
end
