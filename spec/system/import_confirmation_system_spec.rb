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
      results: [{ kind: 'ebook', trackId: 42, trackName: 'The imported book', artistName: 'Detail author',
                  sellerName: 'Detail publisher', releaseDate: '2020-01-01',
                  description: 'A description from the source' }]
    }.to_json)
  end

  def expect_logged_book_page
    settled = 'html:not([aria-busy="true"]):not([data-turbo-preview]):not(:active-view-transition)'
    expect(page).to have_css("#{settled} .media-detail", visible: :all)
  end

  it 'searches a title entered before the import controller connects' do
    script = page.driver.browser.execute_cdp('Page.addScriptToEvaluateOnNewDocument', source: <<~JS)
      const observer = new MutationObserver(() => {
        const title = document.querySelector('[data-thumbnail-fetcher-target~="titleInput"]');
        if (!title) return;
        const form = title.closest('[data-controller~="thumbnail-fetcher"]');
        window.enteredBeforeImportConnected = form?.dataset.connected !== 'true';
        title.value = 'The imported book';
        title.dispatchEvent(new Event('input', { bubbles: true }));
        observer.disconnect();
      });
      observer.observe(document, { childList: true, subtree: true });
    JS
    visit new_book_path
    expect(page).to have_css('[data-controller~="thumbnail-fetcher"][data-connected="true"]')
    expect(page.evaluate_script('window.enteredBeforeImportConnected')).to be true
    expect(page).to have_field('Title', with: 'The imported book')
    find('[role="button"][aria-label="Select The imported book"]').click
    expect(page).to have_text('Source details loaded')
    expect(page).to have_text('Detail author')
    capture_ui_screenshot('import-early-input-recovered')
  ensure
    page.driver.browser.execute_cdp('Page.removeScriptToEvaluateOnNewDocument', identifier: script['identifier']) if script
  end

  it 'confirms imported metadata, keeps personal fields editable and offers manual correction at desktop and mobile' do
    visit new_book_path
    expect(page).to have_css('[data-controller~="thumbnail-fetcher"][data-connected="true"]')
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
    expect_logged_book_page
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
    expect_logged_book_page
    expect(page).to have_text('Book was successfully logged.')
    expect(Book.last.author).to eq('Search author')
  end

  it 'preserves the import and manual field boundary for every media type' do
    %w[movie tv_show album book comic video_game].each do |type|
      allow(MediaSearchService).to receive(:request).and_return(
        state: 'ready', results: [{ title: 'A selected title', api_id: 'wiki_42', source: 'Wikipedia' }]
      )
      visit public_send("new_#{type}_path")
      expect(page).to have_css('[data-controller~="thumbnail-fetcher"][data-connected="true"]')
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

  it 'lets readers propose ordinary provider fact corrections without editing JSON or changing the catalog directly' do
    book = Book.create!(title: 'A sourced book', metadata_details: { 'number_of_pages' => 300, 'subjects' => ['Fiction'] })
    visit new_book_edit_suggestion_path(book)
    expect(page).to have_field('Pages', with: '300')
    fill_in 'Pages', with: '320'
    fill_in 'Subjects', with: "Fiction\nHistory"
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    capture_ui_screenshot('import-correction-mobile')
    click_button 'Submit Suggestion'
    expect(page).to have_text('Edit suggestion submitted successfully and is pending review.')
    expect(book.reload.metadata_details['number_of_pages']).to eq(300)
    expect(EditSuggestion.last.proposed_changes['metadata_details']).to include('number_of_pages' => '320')
  end

  it 'preserves early title focus when deferred modal autofocus runs' do
    script = page.driver.browser.execute_cdp('Page.addScriptToEvaluateOnNewDocument', source: <<~JS)
      (() => {
        const observer = new MutationObserver(() => {
          const modal = document.querySelector('[data-controller~="modal"][data-connected="true"]');
          const title = modal?.querySelector('[data-thumbnail-fetcher-target~="titleInput"]');
          if (!title) return;
          observer.disconnect();
          title.focus();
          requestAnimationFrame(() => {
            modal.dataset.earlyFocusRetained = String(document.activeElement === title);
          });
        });
        observer.observe(document, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-connected'] });
      })();
    JS
    visit new_book_path
    expect(page).to have_css('[data-early-focus-retained="true"]')
    fill_in 'Title', with: 'The imported book'
    find('[role="button"][aria-label="Select The imported book"]').click
    expect(page).to have_text('Source details loaded')
    expect(page).to have_text('Detail author')
  ensure
    page.driver.browser.execute_cdp('Page.removeScriptToEvaluateOnNewDocument', identifier: script['identifier']) if script
  end
end
