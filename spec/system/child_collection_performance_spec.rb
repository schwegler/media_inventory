# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Large child collections', type: :system do
  it 'navigates issue pages with native history, focus and responsive controls' do
    comic = Comic.create!(title: 'New X-Men pagination')
    ComicIssue.insert_all!(46.times.map { |i| { comic_id: comic.id, issue_number: i + 1, title: "Chapter #{i + 1}" } })
    visit comic_path(comic, child_status: 'all', page: 3)
    expect(page).to have_css('.series-pagination', text: '1–30 of 46 issues')
    page.execute_script(<<~JS)
      const next = document.querySelector('.series-pagination a[rel=next]'); next.click(); next.click()
    JS
    expect(page).to have_css('.series-pagination', text: '31–46 of 46 issues')
    expect(page).to have_css('#series-entries .series-entry', count: 16)
    expect(URI.parse(page.current_url).fragment).to eq('media-entries')
    expect(page.evaluate_script('document.activeElement.id')).to eq('media-entries')
    page.execute_script(<<~JS)
      document.querySelector('.series-pagination').scrollIntoView({block: 'center', behavior: 'instant'})
    JS
    page.driver.browser.execute_async_script(
      'Promise.all(document.getAnimations().map(a => a.finished)).then(arguments[0])'
    )
    expect(page).to have_css('.series-pagination a[rel=prev]')
    capture_ui_screenshot('issue-pagination-desktop')
    page.go_back
    expect(page).to have_css('.series-pagination', text: '1–30 of 46 issues')
    page.go_forward
    expect(page).to have_css('.series-pagination', text: '31–46 of 46 issues')
    page.refresh
    expect(page).to have_css('#series-entries .series-entry', count: 16)
    resize_browser_viewport(390, 844)
    page.execute_script(<<~JS)
      document.querySelector('.series-pagination').scrollIntoView({block: 'center', behavior: 'instant'})
    JS
    page.driver.browser.execute_async_script(
      'Promise.all(document.getAnimations().map(a => a.finished)).then(arguments[0])'
    )
    capture_ui_screenshot('issue-pagination-mobile')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    within('.series-pagination') { click_link 'Previous' }
    expect(page).to have_css('#series-entries .series-entry', count: 30)
  end

  it 'bounds the DOM while preserving season, search and pagination through real requests' do
    series = TvShow.create!(title: 'Large collection')
    TvEpisode.insert_all!(100.times.map do |index|
      { tv_show_id: series.id, name: "Episode #{index + 1}", season: index < 60 ? 1 : 2, episode: index + 1 }
    end)
    visit tv_show_path(series)
    expect(page).to have_css('[data-controller="series-navigation"][data-connected="true"]')
    expect(page).to have_text('60 matching episodes')
    expect(page).to have_css('#series-entries .series-entry', count: 30)
    fill_in 'Search episodes', with: 'Episode 12'
    expect(page).to have_text('1 matching episodes')
    expect(page).to have_css('#series-entries .series-entry', count: 1)
    fill_in 'Search episodes', with: ''
    expect(page).to have_text('60 matching episodes')
    select 'Season 2', from: 'Season'
    expect(page).to have_text('40 matching episodes')
    # Interrupt an in-flight Turbo filter submission with a native page visit.
    page.execute_script(<<~JS)
      const form = document.querySelector('.child-collection-toolbar');
      form.querySelector('[name=child_q]').value = 'no such episode';
      form.requestSubmit();
      document.querySelector('#series-entries a[rel=next]').click();
    JS
    expect(page).to have_css('#series-entries .series-entry', count: 10)
    expect(page).to have_field('Search episodes', with: '')
    page.refresh
    expect(page).to have_select('Season', selected: 'Season 2')
    expect(page).to have_css('#series-entries .series-entry', count: 10)
    page.current_window.resize_to(390, 844)
    fill_in 'Search episodes', with: 'no such episode'
    expect(page).to have_text('No matching episodes.')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
  end
end
