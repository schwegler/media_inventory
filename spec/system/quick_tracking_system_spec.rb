# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Quick tracking accessibility', type: :system do
  it 'handles future releases deliberately, keeps unique controls and fits mobile and desktop' do
    user = create_and_login_user
    2.times do |index|
      show = TvShow.create!(title: "Future series #{index}")
      LibraryItem.create!(user: user, item: show)
      pilot = show.tv_episodes.create!(name: 'Pilot', season: 1, episode: 1, air_date: Date.yesterday)
      show.tv_episodes.create!(name: 'Future episode', season: 1, episode: 2, air_date: 1.week.from_now.to_date)
      LibraryItem.create!(user: user, item: pilot, consumed: true, consumed_at: Date.current)
    end
    [390, 1440].each do |width|
      resize_browser_viewport(width, 900)
      visit root_path
      expect(page).to have_css('.in-progress-card', count: 2)
      expect(page).to have_css('.in-progress-next-badge', text: /upcoming/i, count: 2)
      expect(page).to have_no_text('Aired', exact: false)
      expect(page).to have_no_css('.in-progress-log-btn', visible: true)
      first('.in-progress-early summary').click
      expect(first('.in-progress-log-btn')[:'aria-label']).to include('Future series 0').or include('Future series 1')
      card = first('.in-progress-card')
      title = card.find('.in-progress-series-title').text
      options = card.find('.tracking-options > summary')
      options.send_keys(:enter)
      expect(card).to have_button("Dismiss #{title} from In progress", visible: true)
      options.send_keys(:escape)
      expect(card).to have_no_css('.tracking-options[open]')
      expect(card).to have_css('.tracking-options > summary:focus')
      options.send_keys(:space)
      expect(card).to have_button("Dismiss #{title} from In progress", visible: true)
      find('h1').click
      expect(card).to have_no_css('.tracking-options[open]')
      options.click
      expect(card).to have_button("Dismiss #{title} from In progress", visible: true)
      heights = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('.in-progress-dismiss,.in-progress-log-btn,.in-progress-rating-select'))
          .filter(el => el.getClientRects().length).map(el => el.getBoundingClientRect().height)
      JS
      expect(heights.min).to be >= 44
      ids = all('.in-progress-card [id]', visible: :all).map { |element| element[:id] }
      expect(ids.uniq).to eq(ids)
      capture_ui_screenshot("tracking-#{width}")
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    end
  end

  it 'keeps keyboard focus on the next tracking action after a Turbo replacement' do
    user = create_and_login_user
    show = TvShow.create!(title: 'Keyboard series')
    LibraryItem.create!(user: user, item: show)
    episodes = %w[Pilot Second Third].each_with_index.map do |name, index|
      show.tv_episodes.create!(name: name, season: 1, episode: index + 1, air_date: Date.yesterday)
    end
    LibraryItem.create!(user: user, item: episodes.first, consumed: true, consumed_at: Date.current)
    visit root_path
    expect(page).to have_css('.in-progress-card[data-tracking-ready="true"]')
    find_button('Watch Keyboard series · S1E2 · Second').send_keys(:enter)
    expect(page).to have_button('Watch Keyboard series · S1E3 · Third')
    expect(page).to have_css('.in-progress-log-btn:focus')
    expect(user.library_items.find_by(item: episodes.second).consumed).to be true
  end
end
