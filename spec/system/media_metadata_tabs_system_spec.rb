# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metadata tabs', type: :system do
  let!(:movie) do
    Movie.create!(title: 'Metadata browser fixture', director: 'Director fixture',
                  actors: (1..30).map { |n| "Actor fixture #{n}" }.join(', '), genre: 'Drama',
                  release_year: 2026,
                  metadata_details: { 'Overview' => 'A synopsis that stays visible.', 'Runtime' => 90,
                                      'Languages' => ['English'] })
  end

  it 'supports keyboard, history, searchable panels and expanded document presentation' do
    visit movie_path(movie, anchor: 'metadata-cast')
    expect(page).to have_css('#metadata-cast-tab[aria-selected="true"]')
    expect(page).to have_text('Actor fixture 30')
    expect(page).to have_css('#overview', text: 'A synopsis that stays visible.')
    tab = find('#metadata-cast-tab')
    tab.send_keys(:right)
    expect(page).to have_css('#metadata-creators-tab[aria-selected="true"]')
    expect(page.evaluate_script('document.activeElement.id')).to eq('metadata-creators-tab')
    find('#metadata-creators-tab').send_keys(:home)
    expect(page).to have_css('#metadata-details-tab[aria-selected="true"]')
    find('#metadata-details-tab').send_keys(:end)
    expect(page).to have_css('#metadata-taxonomy-tab[aria-selected="true"]')
    find('#metadata-taxonomy-tab').send_keys(:left)
    expect(page).to have_css('#metadata-creators-tab[aria-selected="true"]')
    find('#metadata-taxonomy-tab').click
    expect(page).to have_text('Drama')
    page.go_back
    expect(page).to have_css('#metadata-creators-tab[aria-selected="true"]')
    page.go_forward
    expect(page).to have_css('#metadata-taxonomy-tab[aria-selected="true"]')
    page.execute_script("document.querySelector('#metadata-cast').dispatchEvent(new Event('beforematch'))")
    expect(page).to have_css('#metadata-cast-tab[aria-selected="true"]')
    click_button 'Show all'
    expect(page).to have_text('Actor fixture 30')
    expect(page).to have_text('Director fixture')
    expect(page).to have_no_css('[role="tabpanel"]')
    expect(page).to have_css('#title-details .media-metadata-panel:not([hidden])', count: 4)
    click_button 'Show tabs'
    expect(page).to have_css('[role="tabpanel"]', count: 1)
  end

  it 'reflows long metadata in light and dark themes on desktop, mobile and 200 percent equivalent width' do
    [[1440, 1000], [390, 844], [320, 900]].each do |width, height|
      resize_browser_viewport(width, height)
      visit movie_path(movie, anchor: 'title-details')
      %w[light dark].each do |theme|
        page.execute_script("document.documentElement.dataset.theme = '#{theme}'")
        find('#metadata-cast-tab').click
        expect(page).to have_text('Actor fixture 30')
        expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
        expect(find('#metadata-cast-tab').evaluate_script('this.getBoundingClientRect().height')).to be >= 44
        capture_ui_screenshot("metadata-tabs-#{width}-#{theme}")
      end
    end
  end

  it 'adapts non-film categories while keeping tracks and series entries outside the tabs' do
    book = Book.create!(title: 'Book metadata fixture', author: 'Author fixture', publisher: 'Publisher fixture')
    album = Album.create!(title: 'Album metadata fixture', artist: 'Artist fixture', genre: 'Jazz')
    album.album_tracks.create!(title: 'Track fixture', provider_id: 'track-fixture')
    comic = Comic.create!(title: 'Comic metadata fixture', writer: 'Writer fixture', publisher: 'Publisher fixture')
    comic.comic_issues.create!(title: 'Issue fixture', issue_number: 1)
    show = TvShow.create!(title: 'TV metadata fixture', actors: 'Actor fixture', network: 'Network fixture')
    show.tv_episodes.create!(name: 'Episode fixture', season: 1, episode: 1)
    game = VideoGame.create!(title: 'Game metadata fixture', developer: 'Developer fixture', platform: 'PC',
                             metadata_details: { 'genres' => ['Action'], 'features' => ['Single-player'] })
    [book, album, comic, show, game].each do |item|
      visit polymorphic_path(item)
      expect(page).to have_css('#title-details [role="tablist"]')
      expect(page).to have_no_css('#metadata-cast') unless item.is_a?(TvShow)
      click_button 'Show all'
      expect(page).to have_css('#title-details a.media-category-link')
      expect(page).to have_text('Track fixture') if item == album
      expect(page).to have_text('Issue fixture') if item == comic
      expect(page).to have_text('Episode fixture') if item == show
      expect(page).to have_no_css('#title-details .series-entry, #title-details .album-track')
      capture_ui_screenshot("metadata-#{item.class.name.underscore}-expanded")
    end
  end

  it 'keeps published shelf rows compact and anonymous links usable' do
    owner = User.create!(name: 'Curator fixture', username: 'curator_fixture', email: 'fixture@example.com',
                         password: 'password123', confirmed_at: Time.current)
    owner.shelf_previews.attach(io: File.open(Rails.root.join('spec/fixtures/files/comic-portrait.png')),
                                filename: 'preview.png', content_type: 'image/png')
    previews = [movie] + 4.times.map { |n| Movie.create!(title: "Cover fixture #{n + 1}") }
    previews.each do |title|
      title.cover_image.attach(io: File.open(Rails.root.join('spec/fixtures/files/comic-portrait.png')),
                               filename: 'catalog-cover.png', content_type: 'image/png')
    end
    owner.favorite_shelves.create!(category: 'Movie', picks: previews.map { |title| { type: 'Movie', id: title.id } })
    [[1440, 1000], [390, 844]].each do |width, height|
      resize_browser_viewport(width, height)
      visit movie_path(movie)
      shelf = find('.media-public-shelf')
      page.execute_script("document.querySelector('.media-public-shelves').scrollIntoView({block: 'center'})")
      expect(shelf.evaluate_script('this.getBoundingClientRect().top')).to be < height
      expect(shelf).to have_text('Movies')
      expect(shelf).to have_text('Curator fixture')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
      capture_ui_screenshot("metadata-public-shelf-#{width}")
      shelf.send_keys(:enter)
      expect(page).to have_current_path(shelf_path(owner.username, category: 'Movie'))
    end
  end

  it 'shows every metadata category without JavaScript' do
    page.driver.browser.execute_cdp('Emulation.setScriptExecutionDisabled', value: true)
    visit movie_path(movie, anchor: 'metadata-cast')
    expect(page).to have_text('Actor fixture 30')
    expect(page).to have_text('Director fixture')
    expect(page).to have_text('Drama')
    expect(page).to have_no_css('[role="tab"]')
    capture_ui_screenshot('metadata-tabs-no-js')
  ensure
    page.driver.browser.execute_cdp('Emulation.setScriptExecutionDisabled', value: false)
  end
end
