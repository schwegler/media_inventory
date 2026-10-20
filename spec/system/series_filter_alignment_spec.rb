# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Series filter alignment', type: :system do
  it 'aligns controls across desktop and tablet and stacks compactly on phones' do
    user = create_and_login_user
    user.update!(theme: 'dark')
    show = TvShow.create!(title: 'Episode filter alignment QA')
    LibraryItem.create!(user: user, item: show)
    show.tv_episodes.create!(name: 'First episode', season: 1, episode: 1)
    show.tv_episodes.create!(name: 'Second episode', season: 2, episode: 1)
    visit tv_show_path(show)
    expect(page).to have_css('.child-collection-toolbar[data-connected="true"]')

    [1440, 1024, 768, 580, 390, 320].each do |width|
      resize_browser_viewport(width, 900)
      page.execute_script("document.querySelector('#media-entries').scrollIntoView({ block: 'start' })")
      boxes = page.evaluate_script(<<~JS)
        ['#season', '#child_q', '#child-status', '.series-filter-actions button', '.series-filter-actions a'].map(selector => {
          const rect = document.querySelector(selector).getBoundingClientRect();
          return { top: rect.top, bottom: rect.bottom, height: rect.height, left: rect.left, right: rect.right };
        })
      JS
      expect(boxes.map { |box| box['height'].round }.uniq).to eq([44])
      expect((boxes[3]['top'] - boxes[4]['top']).abs).to be < 1
      if width > 580
        expect(boxes.map { |box| box['top'] }.max - boxes.map { |box| box['top'] }.min).to be < 1
      else
        expect(boxes[0]['bottom']).to be <= boxes[1]['top']
        expect(boxes[1]['bottom']).to be <= boxes[2]['top']
        expect(boxes[2]['bottom']).to be <= boxes[3]['top']
      end
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
      capture_ui_screenshot("series-filters-#{width}")
    end

    find('.series-filters > summary').send_keys(:enter)
    expect(page).to have_no_css('.series-filter-fields', visible: true)
    expect(page).to have_select('Season', visible: true)
    find('.series-filters > summary').send_keys(:enter)
    select 'Season 2', from: 'Season'
    expect(page).to have_css('#series-entries .series-entry-title', text: 'Second episode')
    fill_in 'Search episodes', with: 'no match'
    expect(page).to have_text('No matching episodes')
    find('.series-filter-actions a', text: 'Reset').send_keys(:enter)
    expect(page).to have_css('#series-entries .series-entry-title', text: 'First episode')
    expect(page).to have_field('Search episodes', with: '')
    expect(page).to have_select('Watch status', selected: 'All episodes')
  end
end
