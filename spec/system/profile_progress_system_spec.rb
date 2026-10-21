# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile overview and tracking dashboard', type: :system do
  # rubocop:disable-next Metrics/AbcSize
  def seed_profile(user)
    5.times do |index|
      series = TvShow.create!(title: "Evening series #{index + 1}")
      library = LibraryItem.create!(user: user, item: series, is_collected: true, is_public: true)
      series.cover_image.attach(io: File.open(Rails.root.join('spec/fixtures/files/comic-portrait.png')),
                                filename: 'cover.png')
      3.times do |n|
        series.tv_episodes.create!(name: "Chapter #{n + 1}", season: 1, episode: n + 1, air_date: Date.yesterday)
      end
      LibraryItem.create!(user: user, item: series.tv_episodes.first, consumed: true)
      library.consumption_passes.first.entries.update_all(consumed_at: (index + 1).hours.ago)
    end
    3.times do |index|
      book = Book.create!(title: "Collected book #{index + 1}")
      book.cover_image.attach(io: File.open(Rails.root.join('spec/fixtures/files/comic-portrait.png')),
                              filename: 'cover.png')
      LibraryItem.create!(user: user, item: book, is_collected: true)
    end
    picks = Book.order(:id).last(3).map { |book| { 'type' => 'Book', 'id' => book.id } }
    user.favorite_shelves.create!(category: 'overall', picks: picks)
    user.update!(username: 'overview_reader', bio: 'Stories, records and worlds worth coming back to.')
  end

  def capture_profile(name)
    return unless ENV['UI_QA_DIR']

    FileUtils.mkdir_p(ENV.fetch('UI_QA_DIR'))
    page.execute_script("window.scrollTo({ top: 0, behavior: 'instant' })")
    capture_current(name)
  end

  def capture_current(name)
    return unless ENV['UI_QA_DIR']

    page.driver.browser.execute_async_script(<<~JS)
      const done = arguments[0]; requestAnimationFrame(() => requestAnimationFrame(done))
    JS
    page.driver.browser.save_screenshot(File.join(ENV.fetch('UI_QA_DIR'), "#{name}.png"))
  end

  [390, 1440].each do |width|
    it "keeps one collection row at #{width}px, opens the full dashboard and tracks the next episode" do
      user = create_and_login_user(name: 'Overview Reader')
      seed_profile(user)
      resize_browser_viewport(width, 1000)
      visit handle_profile_path(user.username)
      if ENV['PROFILE_BEFORE'] == '1'
        capture_profile("profile-before-#{width}")
        page.scroll_to(find('h2', text: 'Recently collected'), align: :top)
        page.execute_script('window.scrollBy(0, -110)')
        capture_current("profile-collection-before-#{width}")
        next
      end
      expect(page).to have_css('.profile-progress-preview .in-progress-card', count: 2)
      expect(page).to have_css('.profile-media-row .profile-media-entry', count: 6)
      tops = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('.profile-media-row .profile-media-entry'))
          .map(e => Math.round(e.getBoundingClientRect().top))
      JS
      expect(tops.uniq.size).to eq(1)
      row = find('.profile-media-row')
      row.send_keys(:end)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
      capture_profile("profile-after-#{width}")
      page.scroll_to(find('h2', text: 'Recently collected'), align: :top)
      page.execute_script('window.scrollBy(0, -110)')
      capture_current("profile-collection-after-#{width}")
      click_link 'Open In progress dashboard'
      expect(page).to have_css('.profile-progress-dashboard .in-progress-card', count: 5)
      select 'Title A–Z', from: 'Sort by'
      click_button 'Apply filters'
      expect(page).to have_current_path(/sort=title/)
      expect(first('.in-progress-series-title')).to have_text('Evening series 1')
      expect(page).to have_css('.in-progress-card[data-tracking-ready="true"]')
      first('.in-progress-log-btn').send_keys(:enter)
      expect(page).to have_css('.in-progress-card:first-child .in-progress-next-link', text: 'Chapter 3')
      expect(page).to have_css('.in-progress-log-btn:focus')
      expect(page).to have_text('5 active titles')
      select 'Comics', from: 'Media type'
      click_button 'Apply filters'
      expect(page).to have_text('No matching titles.')
      capture_profile("profile-progress-empty-#{width}")
      click_link 'Reset filters'
      expect(page).to have_css('.in-progress-card', count: 5)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
      capture_profile("profile-dashboard-#{width}")
    end
  end

  it 'refills the overview after completion and handles clipboard fallback accessibly' do
    user = create_and_login_user
    seed_profile(user)
    visit handle_profile_path(user.username)
    page.execute_script("Object.defineProperty(navigator, 'clipboard', { configurable: true, value: undefined })")
    click_button 'Copy profile link'
    expect(page).to have_field('Public profile link', visible: true)
    expect(page).to have_text('Select and copy this link.')
    expect(page).to have_css('input[aria-label="Public profile link"]:focus')
    first('.in-progress-log-btn').click
    expect(page).to have_css('.in-progress-card:first-child .in-progress-next-link', text: 'Chapter 3')
    first('.in-progress-log-btn').click
    expect(page).to have_no_css('.profile-progress-preview .in-progress-series-title', text: 'Evening series 1')
    expect(page).to have_css('.profile-progress-preview .in-progress-card', count: 2)
  end
  it 'keeps private game session and progress actions working in the dark mobile dashboard' do
    user = create_and_login_user
    user.update!(theme: 'dark', username: 'game_reader')
    game = VideoGame.create!(title: 'Night game')
    library = user.library_items.create!(item: game)
    run = library.game_playthroughs.create!(status: 'currently_playing', progress: 20)
    resize_browser_viewport(390, 900)
    visit handle_profile_path(user.username, tab: 'progress', type: 'VideoGame')
    expect(page).to have_text('Private tracking')
    expect(page).to have_text('20%')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
    capture_profile('profile-games-dark-390')
    click_link 'Log session for Night game'
    expect(page).to have_button('Save session')
    click_button 'Save session'
    expect(page).to have_text('Game tracking updated.')
    expect(run.game_sessions.count).to eq(1)
    visit handle_profile_path(user.username, tab: 'progress', type: 'VideoGame')
    click_link 'Update progress for Night game'
    fill_in 'Progress (%)', with: 55
    click_button 'Update playthrough'
    expect(page).to have_no_button('Update playthrough')
    expect(page).to have_text('Game tracking updated.')
    visit handle_profile_path(user.username, tab: 'progress', type: 'VideoGame')
    expect(page).to have_text('55%')
  end
end
