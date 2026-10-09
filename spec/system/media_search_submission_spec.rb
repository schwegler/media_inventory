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

      expect(page).to have_text(/No (covers|matching series) found/)
      expect(page).to have_current_path(new_polymorphic_path(model))
      expect(page).to have_button('Add Manually')
      expect(model.count).to eq(initial_count)
      expect(LibraryItem.count).to eq(0)
    end
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
    click_button 'Create Book'
    expect(page).to have_text('Book was successfully logged.')
    expect(LibraryItem.last.item).to eq(book)
    expect(Book.count).to eq(1)
  end
end
