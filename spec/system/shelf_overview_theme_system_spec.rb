# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shelf overview presentation', type: :system do
  it 'renders every selected palette identically for owner and public, independently of base mode' do
    user = create_and_login_user
    user.update!(username: 'palette_curator', theme: 'light', shelf_headline: 'A synthetic shelf for testing')
    movie = Movie.create!(title: 'Synthetic film')
    user.favorite_shelves.create!(category: 'Movie', picks: [{ type: 'Movie', id: movie.id }])
    palettes = { midnight: '#101117', gallery: '#f5f2eb', electric: '#181235', halloween: '#140f1b',
                 christmas: '#faf2e2', everyday: '#f8f4eb', telly: '#e6f4ff', facet: '#eee5fa',
                 midnight_feature: '#0b090b' }
    palettes.each do |theme, background|
      colors = [shelf_appearance_path(theme: theme, texture: 'paper'),
                shelf_path(user.username, theme: theme, texture: 'paper')].map do |path|
        visit path
        expect(page).to have_css('.favorite-shelf[data-connected="true"]')
        palette = page.evaluate_script(<<~JS)
          (() => { const s = getComputedStyle(document.querySelector('.favorite-shelf'));
            return [s.getPropertyValue('--shelf-bg').trim(), s.color, s.backgroundImage]; })()
        JS
        expect(palette.first).to eq(background)
        expect(palette.last).to include('radial-gradient')
        expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
        palette
      end
      expect(colors.first).to eq(colors.last)
    end
  end

  it 'keeps editing context and presentation through keyboard navigation, theme switching and public return' do
    user = create_and_login_user
    user.update!(username: 'overview_curator', theme: 'dark', shelf_headline: 'A synthetic midnight shelf')
    sources = JSON.parse(Rails.root.join('spec/fixtures/files/discovery_covers/sources.json').read)
    picks = sources.first(5).map do |source|
      item = source.fetch('type').constantize.create!(title: source.fetch('title'))
      item.cover_image.attach(io: File.open(Rails.root.join('spec/fixtures/files/discovery_covers', source.fetch('file'))),
                              filename: source.fetch('file'), content_type: 'image/jpeg')
      { type: item.class.name, id: item.id }
    end
    user.favorite_shelves.create!(category: 'overall', picks: picks)
    visit shelf_appearance_path(theme: 'midnight_feature', texture: 'stars', layout: 'mixtape', companion: 'facet')
    expect(page).to have_css('.favorite-shelf[data-connected="true"]')
    resize_browser_viewport(1280, 900)
    sizes = page.evaluate_script('getComputedStyle(document.querySelector(".favorite-shelf")).backgroundSize')
    expect(sizes).to eq('42px 42px, auto, auto')
    capture_ui_screenshot('shelf-overview-midnight-desktop')
    expect(page).to have_link('Create a custom shelf')
    expect(page).to have_css('.shelf-exhibit', count: 7)
    within('.shelf-exhibition') { first('a').send_keys(:enter) }
    expect(page).to have_text('Editing Overall selections')
    click_link 'Movies', exact: true
    expect(page).to have_text('Editing Movies selections')
    click_link 'View shelf overview', exact: true
    expect(page).to have_text('Viewing shelf overview')
    expect(page).to have_css('[data-shelf-theme="midnight_feature"][data-shelf-texture="stars"]' \
                             '[data-shelf-layout="mixtape"]')
    resize_browser_viewport(390, 844)
    capture_ui_screenshot('shelf-overview-midnight-mobile')
    click_link 'Appearance & sharing', exact: true
    expect(page).to have_css('.shelf-image-settings[open]')
    find('summary', text: 'Advanced appearance').click
    select 'Gallery', from: 'All palettes'
    click_button 'Save appearance', exact: true
    expect(page).to have_text('Appearance saved. Visitors will see this presentation.')
    expect(user.reload.shelf_presentation).to include('theme' => 'gallery', 'texture' => 'stars', 'companion' => 'facet')
    expect(user.favorite_shelves.find_by!(category: 'overall').picks).to eq(picks.map(&:stringify_keys))
    click_link 'View public shelf', exact: true
    expect(page).to have_css('[data-connected="true"][data-favorite-shelf-owner-value="false"][data-shelf-theme="gallery"]')
    expect(page).to have_no_css('.shelf-controls, .shelf-customization, .shelf-collections-empty')
    capture_ui_screenshot('shelf-overview-gallery-public-mobile')
    resize_browser_viewport(1280, 900)
    capture_ui_screenshot('shelf-overview-gallery-public-desktop')
    click_link 'Edit shelf', exact: true
    expect(page).to have_text('Viewing shelf overview')
    expect(page).to have_css('[data-shelf-theme="gallery"][data-shelf-texture="stars"][data-shelf-layout="mixtape"]')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
    capture_ui_screenshot('shelf-overview-gallery-owner-mobile')
    resize_browser_viewport(320, 640)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
    errors = page.driver.browser.logs.get(:browser).select do |entry|
      entry.level == 'SEVERE' && entry.message.match?(/Uncaught|Error connecting controller/)
    end
    expect(errors).to be_empty
  end
end
