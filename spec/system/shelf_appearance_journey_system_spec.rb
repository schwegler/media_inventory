# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shelf appearance editing journey', type: :system do
  it 'takes the owner from public viewing into focused editing and supports undo, save and repeat navigation' do
    user = create_and_login_user
    user.update!(username: 'appearance_journey')
    visit shelf_path(user.username)
    within('.shelf-toolbar') { click_link 'Customize appearance' }
    expect(page).to have_css('.favorite-shelf[data-connected="true"]')
    expect(page).to have_css('#shelf-appearance[open]')
    expect(page).to have_css('#shelf-appearance-heading:focus')
    choose 'Christmas'
    expect(page).to have_text('Unsaved appearance changes. Save to update your public shelf.')
    expect(page).to have_css('.shelf-preview[open]')
    click_button 'Undo appearance changes'
    expect(page).to have_checked_field('Midnight')
    expect(page).to have_text('Appearance changes undone.')
    expect(user.reload.shelf_presentation).to be_blank
    find('#shelf-appearance > summary').click
    within('.shelf-toolbar') { click_link 'Customize appearance' }
    expect(page).to have_css('#shelf-appearance[open]')
    choose 'Gallery'
    dismiss_confirm { click_link 'View public shelf', exact: true }
    expect(page).to have_checked_field('Gallery')
    click_button 'Save appearance'
    within('.shelf-appearance-actions') { expect(page).to have_text('Appearance saved.') }
    expect(user.reload.shelf_presentation).to include('theme' => 'gallery')
    click_link 'Preview the share image'
    expect(page).to have_css('#shelf-image-preview[open]')
    page.go_back
    expect(page).to have_css('#shelf-appearance[open]')
    expect(page).to have_css('#shelf-appearance-heading:focus')
    page.go_forward
    expect(page).to have_css('#shelf-image-preview[open]')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
    within('.shelf-toolbar') { click_link 'Customize appearance' }
    capture_ui_screenshot('shelf-appearance-journey-mobile')
    resize_browser_viewport(1280, 900)
    capture_ui_screenshot('shelf-appearance-journey-desktop')
    choose 'Christmas'
    accept_confirm { click_link 'View public shelf', exact: true }
    expect(page).to have_css('.favorite-shelf[data-shelf-theme="gallery"]')
    within('.shelf-toolbar') { click_link 'Customize appearance' }
    expect(page).to have_checked_field('Gallery')
  end

  it 'keeps direct appearance links in the selected custom shelf and hides editing entry points from visitors' do
    user = create_and_login_user
    user.update!(username: 'custom_appearance')
    collection = user.shelf_collections.create!(title: 'Synthetic collection')
    visit edit_managed_shelf_path(collection.slug, anchor: 'shelf-appearance')
    expect(page).to have_css('#shelf-appearance[open]')
    expect(page).to have_text('These choices apply to this custom shelf.')
    choose 'Christmas'
    click_button 'Save appearance'
    expect(page).to have_text('Appearance saved.')
    expect(collection.reload.presentation).to include('theme' => 'christmas')
    expect(user.reload.shelf_presentation).to be_blank
    click_link 'View public shelf', exact: true
    within('.shelf-toolbar') { click_link 'Customize appearance' }
    expect(page).to have_current_path(/#{Regexp.escape(edit_managed_shelf_path(collection.slug))}/)
    page.driver.browser.manage.delete_all_cookies
    visit shelf_path(user.username, collection: collection.slug)
    expect(page).to have_no_link('Customize appearance')
    expect(page).to have_no_button('Save appearance')
  end
end
