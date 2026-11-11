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
    # The departing editor has the same link label but intercepts its click locally.
    public_shelf = '.favorite-shelf[data-connected="true"][data-favorite-shelf-owner-value="false"]'
    settled_page = 'html:not([aria-busy="true"]):not([data-turbo-preview]):not(:active-view-transition)'
    expect(page).to have_css("#{settled_page}:has(#{public_shelf})", visible: :all)
    within('.shelf-toolbar') { click_link 'Customize appearance' }
    expect(page).to have_current_path(/#{Regexp.escape(edit_managed_shelf_path(collection.slug))}/)
    page.driver.browser.manage.delete_all_cookies
    visit shelf_path(user.username, collection: collection.slug)
    expect(page).to have_no_link('Customize appearance')
    expect(page).to have_no_button('Save appearance')
  end
end

RSpec.describe 'Shelf sharing actions', type: :system do
  it 'opens and focuses sharing from the toolbar repeatedly with keyboard and history navigation' do
    user = create_and_login_user
    user.update!(username: 'share_navigation')
    visit shelf_path(user.username, category: 'overall')
    expect(page).to have_css('.favorite-shelf[data-connected="true"]')
    link = find('.shelf-toolbar a', text: 'Share & export', exact_text: true)
    link.send_keys(:enter)
    expect(page).to have_css('#shelf-appearance[open]')
    expect(page).to have_css('#shelf-share-heading:focus')
    expect(page.evaluate_script('location.hash')).to eq('#shelf-sharing')
    sharing_visible = page.evaluate_script(<<~JS)
      document.querySelector("#shelf-sharing").getBoundingClientRect().top < innerHeight
    JS
    expect(sharing_visible).to be(true)
    find('#shelf-appearance > summary').click
    within('.shelf-toolbar') { click_link 'Share & export' }
    expect(page).to have_css('#shelf-share-heading:focus')
    within('.shelf-toolbar') { click_link 'Customize appearance' }
    expect(page).to have_css('#shelf-appearance-heading:focus')
    page.go_back
    expect(page).to have_css('#shelf-share-heading:focus')
    page.go_forward
    expect(page).to have_css('#shelf-appearance-heading:focus')
    resize_browser_viewport(390, 844)
    visit shelf_path(user.username, category: 'overall')
    within('.shelf-toolbar') { click_link 'Share & export' }
    expect(page).to have_css('#shelf-share-heading:focus')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
    capture_ui_screenshot('shelf-share-navigation-mobile')
  end

  it 'shows local clipboard recovery and native cancel feedback without posting or changing stored state' do
    user = create_and_login_user
    user.update!(username: 'share_feedback')
    visit shelf_path(user.username, category: 'overall')
    expect(page).to have_css('.favorite-shelf[data-connected="true"]')
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'share', { configurable: true, value: undefined });
      Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
        writeText: () => Promise.reject(new Error('Clipboard blocked for test'))
      }});
    JS
    within('.shelf-action-bar') do
      click_button 'Share profile'
      expect(page).to have_text('Clipboard unavailable. Select and copy this profile link:')
      expect(page).to have_css('input[aria-label="Profile link to copy"]:focus')
      expect(find('input[aria-label="Profile link to copy"]').value).to end_with('/@share_feedback')
    end
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'share', { configurable: true, value: () =>
        Promise.reject(Object.assign(new Error('Canceled in test'), { name: 'AbortError' })) });
    JS
    within('.shelf-action-bar') do
      click_button 'Share profile'
      expect(page).to have_text('Sharing canceled. You can try again or copy the profile link.')
    end
    expect(user.reload.shelf_presentation).to be_blank
    resize_browser_viewport(1280, 900)
    capture_ui_screenshot('shelf-share-feedback-desktop')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
    capture_ui_screenshot('shelf-share-feedback-mobile')
  end
end
