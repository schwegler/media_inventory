# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Series entries and review drawers', type: :system do
  def capture_series_screenshot(name)
    return unless ENV['SERIES_QA_DIR']

    page.driver.browser.save_screenshot(File.join(ENV.fetch('SERIES_QA_DIR'), "#{name}.png"))
  end

  it 'filters seasons, saves a private review independently, and updates watch progress' do
    user = create_and_login_user
    user.update!(theme: 'light')
    show = TvShow.create!(title: 'Episode design QA')
    LibraryItem.create!(user: user, item: show)
    episode = show.tv_episodes.create!(name: 'Episode 2', season: 1, episode: 2,
                                       air_date: '2000-07-06', thumbnail_url: '/missing-artwork.png',
                                       summary: 'The group sits around the kitchen table, sharing their life stories.')
    show.tv_episodes.create!(name: 'Next season', season: 3, episode: 1)
    page.current_window.resize_to(1440, 1000)
    visit tv_show_path(show)
    expect(page).to have_select('Season', selected: 'Season 1')
    click_button 'Next season'
    expect(page).to have_select('Season', selected: 'Season 3')
    click_button 'Previous season'
    within "#tv_episode_#{episode.id}" do
      find('.series-entry-details > summary').click
      click_link 'Write review'
    end
    expect(page).to have_css('.review-drawer', visible: true)
    within '.review-drawer' do
      fill_in 'Your review (optional)', with: 'A memorable episode.'
      select '4.5 ★', from: 'Rating'
    end
    capture_series_screenshot('episodes-review-desktop')
    within('.review-drawer') { click_button 'Save review' }
    expect(page).to have_no_css('.review-drawer')
    child_lib = LibraryItem.find_by!(user: user, item: episode)
    expect(child_lib.review).to eq('A memorable episode.')
    expect(child_lib.consumed?).to be false
    expect(child_lib.is_public?).to be false
    within("#tv_episode_#{episode.id}") { click_button 'Mark watched: 2. Episode 2' }
    expect(page).to have_css('[data-child-collection-target="completed"]', text: '1 of 2')
    select 'Unwatched', from: 'Watch status'
    expect(page).to have_text('No matching episodes')
    select 'All episodes', from: 'Watch status'
    fill_in 'Search episodes', with: 'not an episode'
    expect(page).to have_text('No matching episodes')
    fill_in 'Search episodes', with: ''
    page.current_window.resize_to(390, 844)
    within "#tv_episode_#{episode.id}" do
      find('.series-entry-details > summary').click
      click_link 'Edit review'
    end
    expect(page).to have_css('.review-drawer')
    capture_series_screenshot('episodes-review-mobile')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    click_button 'Close review'
    expect(page).to have_no_css('.review-drawer')
    select 'Season 3', from: 'Season'
    page.refresh
    expect(page).to have_select('Season', selected: 'Season 3')
  end

  it 'uses the same issue layout, saves reviews, and preserves history during rereads' do
    user = create_and_login_user
    user.update!(theme: 'light')
    comic = Comic.create!(title: 'Comic design QA')
    series_lib = LibraryItem.create!(user: user, item: comic)
    issue = comic.comic_issues.create!(issue_number: 1, title: 'First issue', release_date: '2026-01-01',
                                       summary: 'A new story begins.')
    comic.comic_issues.create!(issue_number: 2, title: 'Second issue')
    visit comic_path(comic)
    within "#comic_issue_#{issue.id}" do
      find('.series-entry-details > summary').click
      click_link 'Write review'
    end
    within '.review-drawer' do
      fill_in 'Your review (optional)', with: 'Beautiful artwork.'
      select 'Public — visible to others', from: 'Visibility'
      click_button 'Save review'
    end
    expect(page).to have_no_css('.review-drawer')
    expect(LibraryItem.find_by!(user: user, item: issue).is_public?).to be true
    accept_confirm { click_button 'Mark all read' }
    expect(page).to have_css('[data-child-collection-target="completed"]', text: '2 of 2')
    click_button 'Start reread'
    expect(page).to have_css('[data-child-collection-target="completed"]', text: '0 of 2')
    within("#comic_issue_#{issue.id}") { click_button 'Mark read: #1: First issue' }
    expect(page).to have_css('[data-child-collection-target="completed"]', text: '1 of 2')
    within("#comic_issue_#{issue.id}") { click_button 'Undo: #1: First issue' }
    expect(page).to have_css('[data-child-collection-target="completed"]', text: '0 of 2')
    expect(LibraryItem.find_by!(user: user, item: issue).consumed?).to be true
    expect(series_lib.consumption_passes.count).to eq(2)
    within("#comic_issue_#{issue.id}") { find('.series-entry-details > summary').click }
    capture_series_screenshot('comics-desktop')
    page.current_window.resize_to(390, 844)
    page.execute_script("document.querySelector('#media-entries').scrollIntoView({ behavior: 'instant', block: 'start' })")
    capture_series_screenshot('comics-mobile')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
  end
end
