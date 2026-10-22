# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public watch progress UI', type: :system do
  it 'separates readable TV summaries from owner tracking in light and dark on mobile and desktop' do
    owner = create_and_login_user(name: 'Progress Owner')
    page.driver.browser.logs.get(:browser) # Isolate this scenario from earlier deliberate browser errors.
    owner.update!(username: 'public_watch')
    show = TvShow.create!(title: 'A series with a private review')
    library = owner.library_items.create!(item: show, is_public: false, review: 'Hidden review sentinel', rating: 5)
    show.cover_image.attach(io: File.open(Rails.root.join('spec/fixtures/files/comic-portrait.png')), filename: 'cover.png')
    episodes = 4.times.map do |n|
      show.tv_episodes.create!(name: "Chapter #{n + 1}", season: 1, episode: n + 1, air_date: Date.yesterday)
    end
    owner.library_items.create!(item: episodes.first, consumed: true)
    %w[light dark].each do |theme|
      owner.update!(theme: theme)
      [390, 1440].each do |width|
        resize_browser_viewport(width, 1000)
        visit handle_profile_path(owner.username, tab: 'progress', preview: 'public')
        expect(page).to have_css('.in-progress-card', count: 1)
        expect(page).to have_text('1 / 4 episodes')
        expect(page).to have_link('Chapter 2')
        expect(page).to have_text('TV watch progress is public.')
        expect(page).to have_no_text('Hidden review sentinel')
        expect(page).to have_no_css('.in-progress-log-form, .tracking-options, .in-progress-pass-badge')
        expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
        expect(page.driver.browser.logs.get(:browser).select { |entry| entry.level == 'SEVERE' }).to be_empty
        page.scroll_to(find('#in_progress_section'), align: :center)
        capture_ui_screenshot("public-watch-#{theme}-#{width}")
        select 'TV shows', from: 'Media type'
        click_button 'Apply filters'
        expect(page).to have_css('.in-progress-card', count: 1)
        expect(page).to have_current_path(/preview=public/)
        click_link 'Chapter 2'
        expect(page).to have_current_path(tv_episode_path(episodes.second))
      end
    end
    visit handle_profile_path(owner.username, tab: 'progress')
    expect(page).to have_css('.in-progress-card[data-tracking-ready="true"]')
    find('.in-progress-log-btn').click
    expect(page).to have_link('Chapter 3')
    expect(library.reload.is_public).to be false
  end
end
