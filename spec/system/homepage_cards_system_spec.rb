# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Homepage card continuity', type: :system do
  # rubocop:disable-next Metrics/AbcSize, Metrics/MethodLength
  def seed_home(user)
    6.times do |index|
      comic = index.odd?
      series = (comic ? Comic : TvShow).create!(title: "Story #{index}: A wonderfully complicated adventure")
      library = user.library_items.create!(item: series, is_public: true)
      series.cover_image.attach(io: File.open(Rails.root.join('spec/fixtures/files/comic-portrait.png')),
                                filename: 'cover.png')
      entries = 4.times.map do |number|
        if comic
          series.comic_issues.create!(issue_number: number + 1, title: "Chapter #{number + 1}",
                                      release_date: Date.yesterday)
        else
          series.tv_episodes.create!(season: 1, episode: number + 1, name: "Chapter #{number + 1}",
                                     air_date: Date.yesterday)
        end
      end
      user.library_items.create!(item: entries.first, consumed: true)
      library.consumption_passes.first.entries.update_all(consumed_at: index.hours.ago)
    end
    friend = User.create!(name: 'Fellow Reader', email: 'friend@example.com', password: 'password123',
                          confirmed_at: Time.current)
    user.follow(friend)
    movie = Movie.create!(title: 'A favorite from a friend')
    movie.cover_image.attach(io: File.open(Rails.root.join('spec/fixtures/files/comic-portrait.png')),
                             filename: 'cover.png')
    friend.library_items.create!(item: movie, is_public: true, is_collected: true, rating: 4,
                                 review: 'An absorbing story with a generous heart. Well worth returning to.')
  end

  it 'keeps compact surfaces, repeated actions and navigation across themes and widths' do
    user = create_and_login_user
    seed_home(user)
    %w[light dark].each do |theme|
      user.update!(theme: theme)
      [320, 768, 1440].each do |width|
        resize_browser_viewport(width, 1000)
        visit root_path
        expect(page).to have_css('.in-progress-card', count: 6)
        expect(page).to have_css('.dashboard-circle-entry')
        expect(page).to have_css('.popular-review-row', count: 1)
        expect(page).to have_css('.card-2026')
        expect(page).to have_title('Trove', exact: false)
        geometry = page.evaluate_script(<<~JS)
          (() => {
            const cards = [...document.querySelectorAll('.home-dashboard :is(.in-progress-card, .dashboard-circle-entry, .popular-review-row)')];
            const grid = document.querySelector('.in-progress-grid');
            return {
              overflow: document.documentElement.scrollWidth > innerWidth,
              columns: getComputedStyle(grid).gridTemplateColumns.split(' ').length,
              surfaces: cards.every(e => {
                const s = getComputedStyle(e);
                return parseFloat(s.paddingLeft) >= 12 && parseFloat(s.borderTopWidth) === 1 &&
                  s.backgroundColor !== getComputedStyle(document.body).backgroundColor;
              }),
              contained: cards.every(card => [...card.querySelectorAll('button,select,summary,h3,a')]
                .filter(e => e.getClientRects().length).every(e => {
                  const a = e.getBoundingClientRect(), b = card.getBoundingClientRect();
                  return a.left >= b.left - 1 && a.right <= b.right + 1;
                }))
            };
          })()
        JS
        expect(geometry).to include('overflow' => false, 'surfaces' => true, 'contained' => true,
                                    'columns' => (width > 800 ? 2 : 1))
        expect(page.driver.browser.logs.get(:browser).select { |entry| entry.level == 'SEVERE' }).to be_empty
        capture_ui_screenshot("home-cards-#{theme}-#{width}")
        page.scroll_to(find('.popular-review-row'), align: :center)
        capture_ui_screenshot("home-social-#{theme}-#{width}")
        within('.popular-review-row') do
          click_button 'Like', exact: true
          expect(page).to have_button('Unlike (1)')
          click_button 'Unlike (1)'
          expect(page).to have_button('Like', exact: true)
        end
      end
    end
    visit root_path
    card_id = first('.in-progress-card')[:id]
    2.times do |index|
      within("##{card_id}") do
        expect(page).to have_css('.in-progress-next-link', text: "Chapter #{index + 2}")
        find('select').select('★★★★', exact: true)
        find('.in-progress-log-btn').click
      end
      expect(page).to have_css("##{card_id} .in-progress-next-link", text: "Chapter #{index + 3}")
    end
    within("##{card_id}") do
      find('.tracking-options summary').click
      expect(page).to have_button('Dismiss', exact: false)
      find('.tracking-options summary').send_keys(:escape)
      expect(page).to have_no_css('.tracking-options[open]')
      find('.in-progress-series-title a').click
    end
    expect(page).to have_current_path(%r{/(tv_shows|comics)/\d+})
    visit root_path
    click_link 'All active series'
    expect(page).to have_css('.library-profile')
    expect(page).to have_css('.in-progress-card')
  end
end
