# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Title synopsis hierarchy', type: :system do
  before do
    page.driver.browser.navigate.to('about:blank')
    page.driver.browser.logs.get(:browser)
  end

  after do
    expect(page.driver.browser.logs.get(:browser).select { |entry| entry.level == 'SEVERE' }).to be_empty
  end

  def title_records
    prose = "<p>The opening story.</p>#{'A longer story continues. ' * 40}"
    [Movie, TvShow, Book, Album, Comic].map do |klass|
      klass.create!(title: "Synopsis #{klass.name}", metadata_details: {
                      'Overview' => prose,
                      'Runtime' => '96'
                    })
    end + [VideoGame.create!(title: 'Synopsis game', synopsis: prose)]
  end

  it 'promotes prose for every catalog, expands by keyboard, and omits empty prose' do
    title_records.each do |item|
      [1440, 390].each do |width|
        resize_browser_viewport(width, 900)
        visit polymorphic_path(item)
        expect(page).to have_css('.media-identity .media-synopsis', count: 1)
        expect(page).to have_css('h1', text: item.title)
        expect(page).to have_current_path(polymorphic_path(item))
        expect(page).to have_no_css('.media-detail-body .game-description, .media-detail-body .media-description-prose')
        expect(page).to have_no_css('.media-description-row dt', text: /Synopsis|Description/)
        expect(page.evaluate_script(<<~JS)).to be true
          (() => {
            const prose = document.querySelector('.media-synopsis').getBoundingClientRect();
            const facts = document.querySelector('.media-facts').getBoundingClientRect();
            return prose.top < facts.top && prose.width > 300 && document.documentElement.scrollWidth <= innerWidth;
          })()
        JS
        toggle = find('.media-synopsis summary')
        expect(toggle.evaluate_script('this.getBoundingClientRect().height')).to be >= 44
        toggle.send_keys(:enter)
        expect(page).to have_css('.media-synopsis details[open] .child-description-prose',
                                 text: 'A longer story continues.')
        toggle.send_keys(:enter)
        expect(page).to have_no_css('.media-synopsis details[open]')
        capture_ui_screenshot("synopsis-#{item.class.name.underscore}-#{width}")
      end
      item.update!(metadata_details: {}) if item.respond_to?(:metadata_details)
      item.update!(synopsis: nil) if item.respond_to?(:synopsis)
      visit polymorphic_path(item)
      expect(page).to have_no_css('.media-synopsis')
      expect(page).to have_no_link('Details') if item.is_a?(VideoGame)
    end
  end

  it 'keeps quick episode tracking and library actions accessible with a long synopsis' do
    user = create_and_login_user
    show = TvShow.create!(title: 'Tracking story', metadata_details: { 'Overview' => 'Story. ' * 150 })
    library = LibraryItem.create!(user: user, item: show)
    ConsumptionPasses.start(library)
    first = show.tv_episodes.create!(name: 'Pilot', season: 1, episode: 1, air_date: Date.yesterday)
    show.tv_episodes.create!(name: 'Second', season: 1, episode: 2, air_date: Date.yesterday)
    resize_browser_viewport(390, 844)
    visit tv_show_path(show)
    expect(page.evaluate_script(<<~JS)).to be true
      document.querySelector('.media-next-log-form button').getBoundingClientRect().bottom < innerHeight
    JS
    find('.media-next-log-form button').send_keys(:enter)
    expect(page).to have_link('S1E2 · Second')
    expect(user.library_items.find_by!(item: first).consumed).to be true
    click_link 'Track this title'
    expect(page).to have_current_path(tv_show_path(show)) { |uri| uri.fragment == 'my-library' }
    within('#my-library .actions-buttons-row') do
      form = find("input[name='tv_show[is_collected]']", visible: false).find(:xpath, '..')
      form.find('button').send_keys(:enter)
      expect(page).to have_css("input[name='tv_show[is_collected]'][value='false']", visible: false)
    end
    expect(library.reload.is_collected).to be true
  end

  it 'promotes episode and issue descriptions while preserving navigation and tracking' do
    user = create_and_login_user
    show = TvShow.create!(title: 'Parent show')
    comic = Comic.create!(title: 'Parent comic')
    [show, comic].each { |parent| ConsumptionPasses.start(LibraryItem.create!(user: user, item: parent)) }
    episode = show.tv_episodes.create!(name: 'Pilot', season: 1, episode: 1, summary: 'The child story. ' * 60)
    show.tv_episodes.create!(name: 'Next', season: 1, episode: 2)
    issue = comic.comic_issues.create!(title: 'First', issue_number: 1, summary: 'The child story. ' * 60)
    comic.comic_issues.create!(title: 'Next', issue_number: 2)
    [episode, issue].each do |item|
      [1440, 390].each do |width|
        resize_browser_viewport(width, 900)
        visit polymorphic_path(item)
        expect(page).to have_css('.media-identity .child-description', count: 1)
        expect(page).to have_no_css('.child-detail-content .child-description')
        expect(page).to have_link('Next →')
        expect(page).to have_link('Track this title')
        find('.media-synopsis summary').send_keys(:enter)
        expect(page).to have_css('.media-synopsis details[open]')
        find('.media-synopsis summary').send_keys(:enter)
        expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
        capture_ui_screenshot("synopsis-#{item.class.name.underscore}-#{width}")
      end
      click_button(item.is_a?(TvEpisode) ? 'Mark watched' : 'Mark read')
      expect(page).to have_button(item.is_a?(TvEpisode) ? 'Mark unwatched' : 'Mark unread')
      item.update!(summary: nil)
      visit polymorphic_path(item)
      expect(page).to have_no_css('.media-synopsis')
    end
  end
end
