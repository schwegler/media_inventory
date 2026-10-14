# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metadata navigation and mobile layout', type: :system do
  it 'follows artist credits from album to entity and back to a supplied track on a narrow screen' do
    album = Album.create!(title: 'A very long album title that should wrap gracefully', artist: 'Taylor Swift')
    album.album_tracks.create!(title: 'A song from the provider', provider_id: 'itunes:1', track_number: 1,
                               credits: [{ 'name' => 'Guest Artist', 'role' => 'Featured artist' }])
    page.current_window.resize_to(390, 844)
    visit album_path(album)
    within('.media-facts') { click_link 'Taylor Swift' }
    expect(page).to have_css('.entity-hero h1', text: 'Taylor Swift')
    expect(page).to have_link(album.title)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    click_link album.title
    expect(page).to have_content('Track listing')
    within('#album-tracks') { click_link 'Guest Artist' }
    expect(page).to have_css('.entity-hero h1', text: 'Guest Artist')
    click_link "#{album.title} — A song from the provider"
    expect(page).to have_css('#album-tracks')
  end

  it 'searches creator names inside a series without showing unrelated issues' do
    comic = Comic.create!(title: 'Comic discovery')
    first = comic.comic_issues.create!(title: 'First', issue_number: 1,
                                       credits: [{ 'name' => 'Alex Ross', 'role' => 'Cover artist' }])
    second = comic.comic_issues.create!(title: 'Second', issue_number: 2)
    visit comic_path(comic)
    fill_in 'Search issues', with: 'Alex Ross'
    expect(page).to have_css("#comic_issue_#{first.id}")
    expect(page).to have_no_css("#comic_issue_#{second.id}")
    find("#comic_issue_#{first.id} .series-entry-details > summary").click
    expect(page).to have_css("#comic_issue_#{first.id} .child-detail-credits", text: 'Alex Ross')
    click_link 'Alex Ross'
    expect(page).to have_css('.entity-hero h1', text: 'Alex Ross')
    expect(page).to have_link('Comic discovery #1: First')
    expect(page).to have_no_link('Comic discovery #2: Second')
  end
end
