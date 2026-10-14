# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Refined entity and child pages', type: :system do
  def capture(name)
    return unless ENV['ENTITY_QA_DIR']

    page.all('[data-action="flash#dismiss"]', visible: true).each(&:click)
    page.driver.browser.execute_async_script(<<~JS)
      const done = arguments[0];
      requestAnimationFrame(() => requestAnimationFrame(() => {
        const animations = document.getAnimations().filter(a => a.effect?.getTiming().iterations !== Infinity);
        Promise.all(animations.map(a => a.finished.catch(() => {}))).then(done);
      }));
    JS
    page.driver.browser.save_screenshot(File.join(ENV.fetch('ENTITY_QA_DIR'), "#{name}.png"))
  end

  it 'shows scannable credit rows, retains role options, and respects private library scope' do
    user = create_and_login_user
    user.update!(theme: 'light')
    comic = Comic.create!(title: 'The Amazing Spider-Man (1999)')
    LibraryItem.create!(user: user, item: comic)
    issue = comic.comic_issues.create!(issue_number: 41, title: 'Looking Back', release_date: '2002-07-01',
                                       summary: 'Spidey meets Jennifer Hardesty in the condemned building.',
                                       metadata_details: { 'Story arcs' => 'The Spider Totem',
                                                           'Locations' => 'New York City' },
                                       credits: [{ 'name' => 'J. Michael Straczynski', 'role' => 'Writer' },
                                                 { 'name' => 'J. Michael Straczynski', 'role' => 'Editor' }])
    entity = MetadataEntity.find_by!(name: 'J. Michael Straczynski')
    portrait = ENV['ENTITY_QA_PORTRAIT'] || Rails.root.join('spec/fixtures/files/valid-cover.png')
    entity.cover_image.attach(io: File.open(portrait), filename: 'portrait.png', content_type: 'image/png')
    entity.update!(portrait_metadata: { 'source_url' => 'https://commons.wikimedia.org/wiki/File:J._Michael_Straczynski.png',
                                        'credit' => 'Joseph Michael Straczynski', 'license' => 'Public domain' })
    page.current_window.resize_to(1440, 1000)
    visit metadata_entity_path(entity)
    expect(page).to have_css('.entity-work-row', count: 1)
    expect(page).to have_link('#41 · Looking Back')
    capture('person-desktop')
    select 'Writer', from: 'Role'
    click_button 'Apply filters'
    expect(page).to have_css('.entity-work-row', count: 1)
    expect(page).to have_select('Role', options: ['All roles', 'Editor', 'Writer'])
    click_link 'Reset'
    expect(page).to have_css('.entity-work-row', count: 1)
    page.current_window.resize_to(390, 844)
    capture('person-mobile')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    click_link '#41 · Looking Back', match: :first
    expect(page).to have_css('.media-child-detail h1', text: '#41 · Looking Back')
    expect(page).to have_css('.child-detail-credits', count: 1)
    expect(page).to have_no_css('.entity-credits')
    expect(page).to have_no_css('.inline-quick-review-box')
    click_link 'Write review'
    expect(page).to have_css('.review-drawer')
    within '.review-drawer' do
      fill_in 'Your review (optional)', with: 'A thoughtful issue.'
      click_button 'Save review'
    end
    expect(page).to have_no_css('.review-drawer')
    expect(page).to have_text('A thoughtful issue.')
    expect(LibraryItem.find_by!(user: user, item: issue).consumed?).to be false
    click_button 'Mark read'
    expect(page).to have_button('Mark unread')
    click_button 'Mark unread'
    expect(page).to have_button('Mark read')
    expect(page).to have_text('A thoughtful issue.')
    capture('issue-mobile')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    page.current_window.resize_to(1440, 1000)
    capture('issue-desktop')
  end

  it 'consolidates episode credits and retains character context and saved reviews' do
    user = create_and_login_user
    user.update!(theme: 'light')
    show = TvShow.create!(title: 'Battlestar Galactica (2004)')
    LibraryItem.create!(user: user, item: show)
    episode = show.tv_episodes.create!(name: '33', season: 1, episode: 1, air_date: '2004-10-18',
                                       summary: 'The fleet makes a jump to a new location every 33 minutes.',
                                       metadata_details: { 'Runtime' => '45 minutes', 'Production code' => '101' },
                                       credits: [{ 'name' => 'Michael Rymer', 'role' => 'Director' },
                                                 { 'name' => 'Ronald D. Moore', 'role' => 'Writer' },
                                                 { 'name' => 'Sam Witwer', 'role' => 'Guest star',
                                                   'character' => 'Crashdown' }])
    page.current_window.resize_to(1440, 1000)
    visit tv_episode_path(episode)
    expect(page).to have_css('.child-detail-credits', count: 1)
    expect(page).to have_text('Sam Witwer as Crashdown')
    within('.child-detail-facts') { expect(page).to have_no_text('Sam Witwer') }
    click_link 'Write review'
    within '.review-drawer' do
      fill_in 'Your review (optional)', with: 'Tense and memorable.'
      click_button 'Save review'
    end
    expect(page).to have_text('Tense and memorable.')
    click_button 'Mark watched'
    expect(page).to have_button('Mark unwatched')
    click_button 'Mark unwatched'
    expect(page).to have_button('Mark watched')
    expect(page).to have_text('Tense and memorable.')
    capture('episode-desktop')
    page.current_window.resize_to(390, 844)
    capture('episode-mobile')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    within('.child-detail-credits') { click_link 'Ronald D. Moore' }
    expect(page).to have_css('.entity-hero h1', text: 'Ronald D. Moore')
  end
end
