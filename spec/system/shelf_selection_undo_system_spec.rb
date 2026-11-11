# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Recovering shelf selection edits', type: :system do
  it 'restores removed favorites, advances the baseline after saving, and preserves appearance edits on mobile' do
    user = create_and_login_user
    user.update!(username: 'selection_recovery')
    first = Movie.create!(title: 'Synthetic first pick')
    second = Movie.create!(title: 'Synthetic second pick')
    shelf = user.favorite_shelves.create!(category: 'Movie', picks: [{ type: 'Movie', id: first.id },
                                                                     { type: 'Movie', id: second.id }])
    visit edit_favorite_shelf_path('Movie')
    expect(page).to have_css('.favorite-shelf[data-connected="true"]')
    expect(page).to have_button('Undo selection changes', disabled: true)
    click_button "Remove #{first.title} from shelf"
    within('.shelf-selection-actions') { expect(page).to have_text('Unsaved selection changes.') }
    click_button 'Undo selection changes'
    expect(page).to have_css('.shelf-slot h3', text: first.title)
    expect(page).to have_css('.shelf-slot h3', text: second.title)
    expect(page).to have_css('.shelf-selection-actions [data-selection-save]:focus')
    expect(shelf.reload.picks.size).to eq(2)
    resize_browser_viewport(390, 844)
    click_button "Remove #{second.title} from shelf"
    click_button 'Save selections'
    within('.shelf-selection-actions') { expect(page).to have_text('Shelf saved.') }
    expect(shelf.reload.picks).to eq([{ 'type' => 'Movie', 'id' => first.id }])
    find('#shelf-appearance > summary').click
    choose 'Gallery'
    click_button "Remove #{first.title} from shelf"
    click_button 'Undo selection changes'
    expect(page).to have_css('.shelf-slot h3', text: first.title)
    expect(page).to have_no_css('.shelf-slot h3', text: second.title)
    expect(page).to have_checked_field('Gallery')
    expect(page).to have_css('.favorite-shelf[data-shelf-theme="gallery"]')
    expect(user.reload.shelf_presentation).to be_blank
    expect(page).to have_button('Undo selection changes', disabled: true)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
    page.execute_script("document.querySelector('.shelf-selection-actions').scrollIntoView({ block: 'center' })")
    capture_ui_screenshot('shelf-selection-recovery-mobile')
    resize_browser_viewport(1280, 900)
    capture_ui_screenshot('shelf-selection-recovery-desktop')
  end

  it 'keeps a failed custom-shelf save recoverable and repeated picker cancellation leaves the baseline intact' do
    user = create_and_login_user
    user.update!(username: 'collection_recovery')
    movie = Movie.create!(title: 'Synthetic collection pick')
    collection = user.shelf_collections.create!(title: 'Recovery examples', picks: [{ type: 'Movie', id: movie.id }])
    visit edit_managed_shelf_path(collection.slug)
    expect(page).to have_css('.favorite-shelf[data-connected="true"]')
    2.times do
      click_button 'Add a title', exact: true
      expect(page).to have_css('dialog[open]')
      fill_in 'Search titles', with: 'Synthetic'
      click_button 'Close search'
      expect(page).to have_no_css('dialog[open]')
      expect(page).to have_css('button:focus', text: 'Add a title')
      expect(page).to have_button('Undo selection changes', disabled: true)
    end
    page.execute_script(<<~JS)
      const original = window.fetch;
      window.fetch = (url, options) => {
        if (options?.method === 'PATCH' && JSON.parse(options.body || '{}').picks) {
          window.fetch = original;
          return Promise.reject(new Error('Synthetic offline: retry or undo.'));
        }
        return original(url, options);
      };
    JS
    click_button "Remove #{movie.title} from shelf"
    click_button 'Save selections'
    within('.shelf-selection-actions') { expect(page).to have_text('Synthetic offline: retry or undo.') }
    expect(page).to have_button('Undo selection changes', disabled: false)
    expect(collection.reload.picks.size).to eq(1)
    find_button('Undo selection changes').send_keys(:enter)
    expect(page).to have_css('.shelf-slot h3', text: movie.title)
    expect(page).to have_css('.shelf-selection-actions [data-selection-save]:focus')
    expect(page).to have_button('Undo selection changes', disabled: true)
    page.driver.browser.manage.delete_all_cookies
    visit shelf_path(user.username, collection: collection.slug)
    expect(page).to have_css('.favorite-shelf[data-connected="true"]')
    expect(page).to have_no_button('Undo selection changes')
    expect(page).to have_no_button('Save selections')
    expect(page).to have_button('Copy profile link')
  end
end
