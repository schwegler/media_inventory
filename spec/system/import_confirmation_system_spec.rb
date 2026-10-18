# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Import confirmation', type: :system do
  before do
    create_and_login_user
    allow(MediaSearchService).to receive(:request).and_return(
      state: 'ready', results: [{ title: 'The imported book', api_id: 'itunes_42', source: 'iTunes',
                                  author: 'Search author' }]
    )
    stub_request(:get, 'https://itunes.apple.com/lookup?id=42').to_return(body: {
      results: [{ artistName: 'Detail author', sellerName: 'Detail publisher', releaseDate: '2020-01-01',
                  description: 'A description from the source' }]
    }.to_json)
  end

  it 'confirms imported metadata, keeps personal fields editable and offers manual correction at desktop and mobile' do
    visit new_book_path
    expect(page).to have_css('[data-connected="true"]')
    fill_in 'Title', with: 'The imported book'
    find('[role="button"][aria-label="Select The imported book"]').click
    expect(page).to have_text('Source details loaded')
    expect(page).to have_text('Detail author')
    expect(page).to have_text('Detail publisher')
    expect(find('input[name="book[author]"]', visible: :all).value).to eq('Detail author')
    expect(page).not_to have_field('Author', visible: true)
    expect(page).to have_field('Review', visible: true)
    expect(page).to have_button('Confirm and save', disabled: false)
    expect(page).to have_text('Not provided by this source')
    capture_ui_screenshot('import-confirmation-desktop')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    capture_ui_screenshot('import-confirmation-mobile')
    click_button 'Use as manual entry'
    expect(page).to have_field('Author', visible: true, with: 'Detail author')
    expect(page).to have_field('Title', visible: true)
    fill_in 'Author', with: 'My correction'
    expect(find('input[name="book[api_id]"]', visible: :all).value).to eq('')
    expect(find('input[name="book[import_selection]"]', visible: :all).value).to eq('')
    fill_in 'Review', with: 'My review'
    click_button 'Save manual entry'
    expect(page).to have_text('Book was successfully logged.')
    expect(Book.last.author).to eq('My correction')
    expect(Book.last.api_id).to be_blank
    expect(LibraryItem.last.review).to eq('My review')
  end

  it 'shows lookup failure honestly and permits a summary import' do
    stub_request(:get, 'https://itunes.apple.com/lookup?id=42').to_return(status: 503)
    visit new_book_path
    fill_in 'Title', with: 'The imported book'
    find('[role="button"][aria-label="Select The imported book"]').click
    expect(page).to have_text('Source details are unavailable')
    expect(page).to have_text('Search author')
    click_button 'Confirm and save'
    expect(page).to have_text('Book was successfully logged.')
    expect(Book.last.author).to eq('Search author')
  end

  it 'preserves the import and manual field boundary for every media type' do
    %w[movie tv_show album book comic video_game].each do |type|
      allow(MediaSearchService).to receive(:request).and_return(
        state: 'ready', results: [{ title: 'A selected title', api_id: 'wiki_42', source: 'Wikipedia' }]
      )
      visit public_send("new_#{type}_path")
      expect(page).to have_css('[data-connected="true"]')
      fill_in 'Title', with: 'A selected title'
      find('[role="button"][aria-label="Select A selected title"]').click
      expect(page).to have_text('Search summary only')
      expect(page).to have_field('Review', visible: true)
      expect(page).to have_button('Confirm and save')
      expect(page).not_to have_css('.import-confirmation.hidden')
      click_button 'Use as manual entry'
      expect(page).to have_field('Title', visible: true)
      expect(find("input[name='#{type}[api_id]']", visible: :all).value).to eq('')
      expect(find("input[name='#{type}[import_selection]']", visible: :all).value).to eq('')
    end
  end
end
