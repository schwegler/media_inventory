# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shelf Story customization', type: :system do
  it 'applies character themes, shares curated choices and renders a Story-safe export on mobile' do
    user = create_and_login_user
    user.update!(username: 'story_preview')
    movie = Movie.create!(title: 'Clearly synthetic browser sample')
    user.favorite_shelves.create!(category: 'Movie', picks: [{ type: 'Movie', id: movie.id }])
    visit shelf_path(user.username, category: 'Movie')
    expect(page).to have_css('.favorite-shelf[data-connected="true"]')
    choose 'Telly'
    select 'Reading list', from: 'Portrait layout'
    select 'Star field', from: 'Background'
    select 'Telly', from: 'Companion'
    expect(page).to have_css('.favorite-shelf[data-shelf-theme="telly"][data-shelf-texture="stars"]')
    expect(page).to have_css('.shelf-companion img[alt=""][src*="telly_shelf"]')
    expect(find_link('View shelf overview')[:href]).to include('layout=reading', 'texture=stars', 'companion=telly')
    find('input[name="shelf-format"][value="portrait"]').choose
    find('summary', text: 'Share image preview').click
    expect(page).to have_css('.shelf-preview canvas[width="1080"][height="1920"]')
    expect(find('#shelf-image-alt-text', visible: :all).value).to include('reading layout', 'stars texture')
    capture_ui_screenshot('shelf-telly-story-desktop')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    capture_ui_screenshot('shelf-telly-story-mobile')
    select 'None', from: 'Companion'
    expect(page).to have_no_css('.shelf-companion img', visible: true)
    choose 'Facet'
    select 'Match theme', from: 'Companion'
    expect(page).to have_css('.shelf-companion img[alt=""][src*="facet_shelf"]')
  end
  it 'returns from the Overall editor to the showcase using keyboard navigation on mobile' do
    user = create_and_login_user
    user.update!(username: 'overview_navigation')
    visit shelf_path(user.username, category: 'overall', theme: 'electric', layout: 'reading',
                                    texture: 'stars', companion: 'facet')
    expect(page).to have_text('Editing Overall favorites')
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
    expect(page).to have_select('Portrait layout', selected: 'Reading list')
    capture_ui_screenshot('shelf-overview-navigation-mobile')
    click_link 'Edit favorites'
    expect(page).to have_text('Editing Overall favorites')
  end
  it 'renders Midnight Feature in every export layout without changing Halloween' do
    user = create_and_login_user
    user.update!(username: 'midnight_feature')
    visit shelf_path(user.username, category: 'Movie', theme: 'midnight_feature')
    expect(page).to have_checked_field('Midnight Feature')
    expect(page).to have_text('the late show. questionable decisions.')
    find('summary', text: 'Share image preview').click
    expect(page).to have_css('.shelf-preview canvas[width="1200"][height="630"]')
    find('input[name="shelf-format"][value="portrait"]').choose
    ['Exhibition gallery', 'Reading list', 'Collector’s edition'].each do |layout|
      select layout, from: 'Portrait layout'
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
end
