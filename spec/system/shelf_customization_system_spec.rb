# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shelf Story customization', type: :system do
  it 'applies character themes, shares curated choices and renders a Story-safe export on mobile' do
    user = create_and_login_user
    user.update!(username: 'story_preview')
    movie = Movie.create!(title: 'Clearly synthetic browser sample')
    user.favorite_shelves.create!(category: 'Movie', picks: [{ type: 'Movie', id: movie.id }])
    visit shelf_path(user.username, category: 'Movie', theme: 'telly', layout: 'reading')
    expect(page).to have_css('.favorite-shelf[data-connected="true"]')
    choose 'Telly'
    select 'Reading list', from: 'Legacy layout'
    find('summary', text: 'Advanced appearance').click
    select 'Star field', from: 'Background'
    select 'Telly', from: 'Mascot'
    expect(page).to have_css('.favorite-shelf[data-shelf-theme="telly"][data-shelf-texture="stars"]')
    expect(page).to have_css('.shelf-companion img[alt=""][src*="telly_shelf"]')
    expect(find_link('View shelf overview')[:href]).to include('layout=reading', 'texture=stars', 'companion=telly')
    find('input[name="shelf-format"][value="portrait"]').choose
    expect(page).to have_css('.shelf-preview canvas[width="1080"][height="1920"]')
    expect(find('#shelf-image-alt-text', visible: :all).value).to include('reading layout', 'stars texture')
    capture_ui_screenshot('shelf-telly-story-desktop')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    capture_ui_screenshot('shelf-telly-story-mobile')
    select 'None', from: 'Mascot'
    expect(page).to have_no_css('.shelf-companion img', visible: true)
    select 'Facet', from: 'All palettes'
    select 'Match theme', from: 'Mascot'
    expect(page).to have_css('.shelf-companion img[alt=""][src*="facet_shelf"]')
  end
  it 'returns from the Overall editor to the showcase using keyboard navigation on mobile' do
    user = create_and_login_user
    user.update!(username: 'overview_navigation')
    visit shelf_path(user.username, category: 'overall', theme: 'electric', layout: 'reading',
                                    texture: 'stars', companion: 'facet')
    expect(page).to have_text('Editing Overall selections')
    capture_ui_screenshot('shelf-overview-navigation-desktop')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
    overview = find_link('View shelf overview')
    page.execute_script('arguments[0].focus()', overview)
    expect(overview).to match_css(':focus')
    overview.send_keys(:enter)
    expect(page).to have_text('Viewing shelf overview')
    expect(page).to have_css('.shelf-introduction')
    expect(page).to have_css('.favorite-shelf[data-shelf-theme="electric"][data-shelf-texture="stars"]')
    expect(page).to have_select('Legacy layout', selected: 'Reading list')
    capture_ui_screenshot('shelf-overview-navigation-mobile')
    click_link 'Edit selections'
    expect(page).to have_text('Editing Overall selections')
  end
  it 'renders Midnight Feature in every export layout without changing Halloween' do
    user = create_and_login_user
    user.update!(username: 'midnight_feature')
    visit shelf_path(user.username, category: 'Movie', theme: 'midnight_feature')
    expect(page).to have_checked_field('Midnight Feature')
    expect(page).to have_text('the late show. questionable decisions.')
    expect(page).to have_css('.shelf-preview canvas[width="1080"][height="1920"]')
    find('input[name="shelf-format"][value="portrait"]').choose
    %w[Gallery Feature Mixtape].each do |layout|
      choose "#{layout} layout"
      expect(page).to have_css('.shelf-preview canvas[width="1080"][height="1920"]')
      expect(find('#shelf-image-alt-text', visible: :all).value).to include('Midnight Feature')
    end
    capture_ui_screenshot('midnight-feature-desktop')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
    capture_ui_screenshot('midnight-feature-mobile')
    choose 'Halloween'
    expect(page).to have_css('.favorite-shelf[data-shelf-theme="halloween"]')
  end
  it 'carries the saved custom headline into category views and every share layout' do
    user = create_and_login_user
    user.update!(username: 'themed_selections', shelf_headline: "it's finally spooky szn 🦇")
    visit shelf_path(user.username, category: 'Book', theme: 'halloween')
    expect(page).to have_css('h1 .shelf-custom-title', text: user.shelf_headline)
    expect(page).to have_css('h1 > span', text: 'Books · selections')
    expect(find('#shelf-image-alt-text', visible: :all).value).to include(user.shelf_headline, 'Category: Books')
    find('input[name="shelf-format"][value="portrait"]').choose
    %w[Gallery Feature Mixtape].each do |layout|
      choose "#{layout} layout"
      expect(find('#shelf-image-alt-text', visible: :all).value).to include(user.shelf_headline)
      expect(page).to have_css('.shelf-preview canvas[height="1920"]')
    end
    capture_ui_screenshot('custom-headline-category-desktop')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
    capture_ui_screenshot('custom-headline-category-mobile')
    click_button 'Save appearance'
    expect(page).to have_text('Appearance saved.')
    click_link 'View shelf overview'
    expect(page).to have_css('h1', text: user.shelf_headline)
    expect(user.reload.shelf_headline).to eq("it's finally spooky szn 🦇")
  end
end
