# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Title reading hierarchy', type: :system do
  let!(:show) do
    actors = (1..30).map { |n| "Actor #{n}" }.join(', ')
    TvShow.create!(title: 'Newlyweds hierarchy fixture', release_year: 2026, network: 'Fixture network',
                   director: 'Fixture director', writer: 'Fixture writer', actors: actors,
                   metadata_details: { 'language' => 'English', 'Runtime' => '30',
                                       'Overview' => ('A long synopsis about the series. ' * 60) })
  end

  before do
    # Chrome can retain errors from earlier broken-artwork examples. Keep this
    # page's console assertion strict, without inheriting their log buffer.
    page.driver.browser.navigate.to('about:blank')
    page.driver.browser.logs.get(:browser)
  end

  def add_articles(item, count: 1)
    count.times do |index|
      title = "A different perspective on this title — story #{index + 1}"
      title += ' and the details that stay with us' * 6 if index.zero?
      article = EditorialArticle.create!(wordpress_id: 500 + index,
                                         title: title,
                                         excerpt: 'A closer look at the story, and what to notice next.',
                                         canonical_url: "https://tacobout.online/story-#{index}/",
                                         published_at: Time.utc(2026, 10, 23) - index.days,
                                         source_modified_at: Time.current, checked_at: Time.current,
                                         image_url: 'https://tacobout.online/wp-content/uploads/2026/10/fixture.png')
      article.editorial_article_titles.create!(item: item)
    end
    allow(Editorial::Urls).to receive(:image).and_call_original
    allow(Editorial::Urls).to receive(:image)
      .with('https://tacobout.online/wp-content/uploads/2026/10/fixture.png')
      .and_return(ActionController::Base.helpers.asset_path('brand/trove_logo_dark_card.png'))
  end

  def check_priority_layout(_width)
    geometry = page.evaluate_script(<<~JS)
      (() => {
      const rect = selector => document.querySelector(selector).getBoundingClientRect();
      const reading = rect('#from-tacobout'), library = rect('#my-library');
      return {readingTop:reading.top,readingBottom:reading.bottom,readingLeft:reading.left,
        libraryTop:library.top,libraryBottom:library.bottom,libraryRight:library.right,
        detailsTop:rect('#title-details').top,entriesTop:rect('#media-entries').top,
        overflow:document.documentElement.scrollWidth>innerWidth};
      })()
    JS
    expect(geometry['overflow']).to be false
    expect(geometry['readingBottom']).to be < [geometry['detailsTop'], geometry['entriesTop']].min
    expect(geometry['readingTop']).to be >= geometry['libraryBottom']
    expect(geometry['readingLeft']).to be < geometry['libraryRight']
    expect(geometry['readingBottom'] - geometry['readingTop']).to be < 360
  end

  it 'puts a readable reading strip ahead of long metadata and episode lists for visitors' do
    70.times { |n| show.tv_episodes.create!(name: "Episode #{n + 1}", season: 1, episode: n + 1) }
    add_articles(show, count: 6)
    [[1440, 1000], [390, 844]].each do |width, height|
      resize_browser_viewport(width, height)
      visit tv_show_path(show)
      expect(page).to have_link('Log in', href: login_path)
      expect(page).to have_css('.editorial-article-card', count: 1)
      check_priority_layout(width)
      capture_ui_screenshot("reading-hierarchy-visitor-#{width}-overview")
      find('.media-section-nav a[href="#from-tacobout"]').click
      expect(page).to have_css('.media-section-nav a[href="#from-tacobout"][aria-current="location"]')
      capture_ui_screenshot("reading-hierarchy-visitor-#{width}-reading")
      find('.editorial-more summary').send_keys(:enter)
      expect(page).to have_css('.editorial-article-card', count: 6)
      expect(page).to have_link('A different perspective on this title — story 6')
      find('.editorial-more summary').send_keys(:enter)
      expect(page).to have_css('.editorial-article-card', count: 1)
      %w[my-library title-details media-entries community comments overview].each do |id|
        find(".media-section-nav a[href='##{id}']").click
        expect(page).to have_current_path(tv_show_path(show)) { |uri| uri.fragment == id }
        expect(page).to have_css(".media-section-nav a[href='##{id}'][aria-current='location']")
      end
      expect(page.driver.browser.logs.get(:browser).select { |entry| entry.level == 'SEVERE' }).to be_empty
    end
  end

  it 'keeps next-episode tracking and library controls first for the owner' do
    user = create_and_login_user
    library = LibraryItem.create!(user: user, item: show)
    ConsumptionPasses.start(library)
    first = show.tv_episodes.create!(name: 'Pilot', season: 1, episode: 1, air_date: Date.yesterday)
    show.tv_episodes.create!(name: 'Second', season: 1, episode: 2, air_date: Date.yesterday)
    add_articles(show)
    [[1440, 1000], [390, 844]].each do |width, height|
      resize_browser_viewport(width, height)
      visit tv_show_path(show)
      check_priority_layout(width)
      expect(page).to have_css('.media-next-log-form button', text: 'Mark watched')
      expect(page).to have_css('#my-library .actions-buttons-row button')
      capture_ui_screenshot("reading-hierarchy-owner-#{width}-overview")
      find('.media-section-nav a[href="#from-tacobout"]').click
      capture_ui_screenshot("reading-hierarchy-owner-#{width}-reading")
    end
    find('.media-next-log-form button').click
    expect(page).to have_link('S1E2 · Second')
    expect(user.library_items.find_by!(item: first).consumed).to be true
    expect(page).to have_css('#from-tacobout .editorial-article-card', count: 1)
    within('#my-library .actions-buttons-row') do
      form = find("input[name='tv_show[is_collected]']", visible: false).find(:xpath, '..')
      form.find('button').send_keys(:enter)
      expect(page).to have_css("input[name='tv_show[is_collected]'][value='false']", visible: false)
    end
    expect(user.library_items.find_by!(item: show).is_collected).to be true
  end

  it 'keeps comic quick reading and child tracking ahead of companion stories' do
    user = create_and_login_user
    comic = Comic.create!(title: 'Comic hierarchy fixture', writer: 'Fixture writer', artist: 'Fixture artist')
    library = LibraryItem.create!(user: user, item: comic)
    ConsumptionPasses.start(library)
    issues = 7.times.map do |index|
      comic.comic_issues.create!(title: "Story #{index + 1}", issue_number: index + 1, release_date: Date.yesterday.to_s)
    end
    add_articles(comic)
    article = EditorialArticle.find_by!(wordpress_id: 500)
    article.editorial_article_titles.create!(item: issues.first)
    [1440, 390].each do |width|
      resize_browser_viewport(width, 900)
      visit comic_path(comic)
      check_priority_layout(width)
      expect(page).to have_css('.media-next-log-form button', text: 'Mark read')
      capture_ui_screenshot("reading-hierarchy-comic-#{width}")
      visit comic_issue_path(issues.first)
      expect(page).to have_css(".media-priority #comic_issue_tracking_#{issues.first.id}")
      expect(page).to have_css('.media-priority #from-tacobout')
      expect(page).to have_button('Mark read')
      capture_ui_screenshot("reading-hierarchy-child-#{width}")
    end
    click_button 'Mark read'
    expect(page).to have_button('Mark unread')
    expect(user.library_items.find_by!(item: issues.first).consumed).to be true
    expect(page).to have_css('#from-tacobout .editorial-article-card', count: 1)
  end

  it 'preserves the original library layout and episode navigation when no articles exist' do
    show.tv_episodes.create!(name: 'Pilot', season: 1, episode: 1)
    [1440, 390].each do |width|
      resize_browser_viewport(width, 900)
      visit tv_show_path(show)
      expect(page).to have_no_css('.media-priority, #from-tacobout, .editorial-more')
      expect(page).to have_css('.media-detail-main #my-library')
      find('.media-section-nav a[href="#media-entries"]').click
      expect(page).to have_text('Pilot')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
      capture_ui_screenshot("reading-hierarchy-no-card-#{width}")
    end
  end
end
