# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Focused owner shelf flow', type: :system do
  it 'creates, adds, saves, views and edits with keyboard-safe cancellation on mobile' do
    user = create_and_login_user
    expect(page).to have_no_css('form[action="/login"]')
    user.update!(username: 'workspace_flow', theme: 'dark', shelf_presentation: { theme: 'halloween' })
    movie = Movie.create!(title: 'A winter discovery')
    sources = JSON.parse(Rails.root.join('spec/fixtures/files/discovery_covers/sources.json').read)
    picks = [sources[0], sources[4]].map do |source|
      item = source.fetch('type').constantize.create!(title: source.fetch('title'))
      item.cover_image.attach(io: File.open(Rails.root.join('spec/fixtures/files/discovery_covers', source.fetch('file'))),
                              filename: source.fetch('file'), content_type: 'image/jpeg')
      { type: item.class.name, id: item.id }
    end
    user.shelf_collections.create!(title: 'Winter nights', description: 'Music and stories for long evenings.',
                                   picks: picks)
    resize_browser_viewport(1280, 900)
    visit shelf_workspace_path
    page.driver.browser.execute_async_script(<<~JS)
      const done = arguments[0];
      Promise.all(Array.from(document.querySelectorAll('.workspace-covers img')).map(img => img.decode().catch(() => {}))).then(done)
    JS
    decoded = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('.workspace-covers img')).every(img => img.naturalWidth > 0)
    JS
    expect(decoded).to be(true)
    capture_ui_screenshot('workspace-overview-dark-desktop')
    resize_browser_viewport(390, 844)
    click_link 'Create shelf', exact: true
    fill_in 'Shelf title', with: 'Evening discoveries'
    fill_in 'A little context (optional)', with: 'Books and films for a quiet evening.'
    select 'Halloween', from: 'Starting mood'
    capture_ui_screenshot('workspace-create-dark-mobile')
    click_button 'Create shelf'
    expect(page).to have_text('Editing shelf')
    click_button 'Add a title', exact: true
    fill_in 'Search titles', with: 'winter'
    click_button 'A winter discovery · Movie'
    click_button 'Save shelf', exact: true
    expect(page).to have_text('Shelf saved. Your public shelf is ready to share.')
    collection = user.shelf_collections.find_by!(title: 'Evening discoveries')
    expect(collection.picks).to eq([{ 'type' => 'Movie', 'id' => movie.id }])
    click_link 'View public shelf', exact: true
    expect(page).to have_no_button('Save shelf')
    expect(page).to have_no_css('.shelf-controls')
    click_link 'Edit shelf', exact: true
    click_link 'Shelf settings', exact: true
    expect(page).to have_css('h1', text: 'Shelf settings')
    capture_ui_screenshot('workspace-settings-dark-mobile')
    fill_in 'Shelf title', with: 'Unsaved changes'
    click_link 'Cancel', exact: true
    expect(page).to have_css('dialog[open]')
    expect(page).to have_css('button:focus', text: 'Keep editing')
    capture_ui_screenshot('workspace-leave-dialog-mobile')
    click_button 'Keep editing'
    expect(page).to have_field('Shelf title', with: 'Unsaved changes')
    click_link 'Cancel', exact: true
    click_button 'Discard changes'
    expect(page).to have_css('h1', text: 'Evening discoveries')
    expect(collection.reload.title).to eq('Evening discoveries')
    click_link 'Shelf settings', exact: true
    fill_in 'Shelf title', with: 'Saved discoveries'
    fill_in 'Overview cover count', with: '1'
    click_button 'Save changes'
    expect(page).to have_css('h1', text: 'Saved discoveries')
    expect(collection.reload.picks.size).to eq(1)
    click_link 'Shelves workspace', exact: true
    expect(page).to have_css('h1', text: 'Shelves')
    expect(page).to have_css('#favorites-heading ~ .workspace-row', count: 7)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
    capture_ui_screenshot('workspace-overview-dark-mobile')
    click_link 'View public shelves', exact: true
    expect(page).to have_css('.favorite-shelf[data-favorite-shelf-owner-value="false"]')
    background = page.evaluate_script('getComputedStyle(document.querySelector(".shelf-section-heading")).backgroundColor')
    expect(background).to eq('rgba(0, 0, 0, 0)')
    expect(page).to have_no_css('.shelf-controls, #new-shelf, .shelf-settings')
    capture_ui_screenshot('workspace-public-overview-halloween-mobile')
  end

  it 'keeps form tokens readable in light and dark modes and at reflow width' do
    user = create_and_login_user
    expect(page).to have_no_css('form[action="/login"]')
    user.update!(username: 'workspace_tokens')
    %w[light dark].each do |theme|
      user.update!(theme: theme)
      resize_browser_viewport(640, 450)
      visit new_managed_shelf_path
      expect(page).to have_css("html[data-theme='#{theme}']")
      expect(page).to have_css('h1', text: 'Create shelf')
      select = find_field('Starting mood')
      colors = page.evaluate_script(<<~JS)
        (() => { const e = document.querySelector('#starting_mood'), s = getComputedStyle(e);
          return { background: s.backgroundColor, foreground: s.color, repeat: s.backgroundRepeat }; })()
      JS
      expect(colors[:background] || colors['background']).not_to eq(colors[:foreground] || colors['foreground'])
      expect(colors[:repeat] || colors['repeat']).to eq('no-repeat')
      select.send_keys(:tab)
      expect(page).to have_css('input[type=submit]:focus')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
      capture_ui_screenshot("workspace-create-#{theme}-reflow")
    end
  end
end
