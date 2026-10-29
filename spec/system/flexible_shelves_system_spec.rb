# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Flexible shelf workspace', type: :system do
  it 'keeps twelve mixed selections through keyboard reorder, settings, light/dark and mobile reflow' do
    user = create_and_login_user
    user.update!(username: 'flexible_browser')
    items = [Book, Movie, Album, VideoGame, TvShow, Comic].flat_map do |model|
      2.times.map { |index| model.create!(title: "#{model.name} selection #{index} with a long readable title") }
    end
    collection = user.shelf_collections.create!(title: 'Winter discoveries',
                                                description: 'Stories, sounds and worlds for slower evenings.',
                                                picks: items.map { |item| { type: item.class.name, id: item.id } })
    visit edit_managed_shelf_path(collection.slug)
    expect(page).to have_css('.favorite-shelf[data-connected="true"]')
    expect(page).to have_css('.shelf-slot', count: 12)
    first_title = items.first.title
    find_button("Move #{first_title} later").send_keys(:enter)
    click_button 'Save shelf'
    expect(page).to have_text('Shelf saved.')
    expect(collection.reload.picks[1]['id']).to eq(items.first.id)
    expect(collection.picks[1]['type']).to eq('Book')
    click_link 'Shelf settings', exact: true
    fill_in 'Overview cover count', with: 2
    click_button 'Save changes'
    expect(page).to have_css('.shelf-slot', count: 12)
    expect(collection.reload.preview_length).to eq(2)
    capture_ui_screenshot('flexible-owner-desktop')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
    capture_ui_screenshot('flexible-owner-mobile')
    click_button 'Add a title', exact: true
    expect(page).to have_css('dialog[open] input:focus')
    find('dialog input').send_keys(:escape)
    expect(find_button('Add a title', exact: true)).to match_css(':focus')
    find('summary', text: 'Appearance & share image').click
    choose 'Gallery', exact: true
    click_button 'Save appearance'
    expect(page).to have_text('Appearance saved.')
    expect(collection.reload.presentation['theme']).to eq('gallery')
    find('summary', text: 'More shelf actions').click
    click_link 'Preview as visitor'
    expect(page).to have_no_button('Save shelf')
    expect(page).to have_no_css('.shelf-settings')
    expect(page).to have_css('.shelf-slot', count: 12)
    expect(page).to have_css('[data-shelf-theme="gallery"]')
    capture_ui_screenshot('flexible-visitor-light-mobile')
    resize_browser_viewport(640, 450)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
    capture_ui_screenshot('flexible-200-percent-reflow')
  end

  it 'returns keyboard focus to Add after removing the final title and saves an empty shelf' do
    user = create_and_login_user
    user.update!(username: 'empty_shelf_browser')
    book = Book.create!(title: 'The final title')
    Book.create!(title: 'Replacement title')
    shelf = user.shelf_collections.create!(title: 'A shelf taking shape', picks: [{ type: 'Book', id: book.id }])
    visit edit_managed_shelf_path(shelf.slug)
    expect(page).to have_css('.shelf-slot', count: 1)
    click_button 'Choose pick 1'
    select 'Books', from: 'Media type'
    fill_in 'Search titles', with: 'Replacement'
    find('.shelf-result', text: 'Replacement title').click
    expect(page).to have_no_css('dialog[open]')
    expect(find_button('Choose pick 1')).to match_css(':focus')
    find_button('Remove Replacement title from shelf').send_keys(:enter)
    expect(page).to have_no_css('.shelf-slot')
    expect(find_button('+ Add a title', exact: true)).to match_css(':focus')
    click_button 'Save shelf'
    expect(page).to have_text('Shelf saved.')
    expect(shelf.reload.picks).to eq([])
    find('summary', text: 'More shelf actions').click
    click_link 'Preview as visitor'
    expect(page).to have_text('A shelf taking shape.')
    expect(page).to have_no_button('Save shelf')
    expect(page).to have_no_button('Add a title')
  end
end
