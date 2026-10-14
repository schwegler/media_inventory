# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metadata detail layout', type: :system do
  it 'keeps mobile biographies readable and filter controls unclipped in dark mode' do
    entity = MetadataEntity.create!(name: 'Alexandria Catherine Montgomery-Wellington', kind: 'person',
                                    description: 'A creator working across comics, books, and film. ' * 8,
                                    portrait_checked_at: Time.current)
    page.current_window.resize_to(390, 844)
    visit metadata_entity_path(entity)
    page.execute_script("document.documentElement.dataset.theme = 'dark'")

    expect(page).to have_css('.entity-hero h1', text: entity.name)
    expect(page.evaluate_script(<<~JS)).to be true
      (() => {
        const hero = document.querySelector('.entity-hero').getBoundingClientRect();
        const bio = document.querySelector('.entity-bio').getBoundingClientRect();
        const header = document.querySelector('.app-header').getBoundingClientRect();
        const button = document.querySelector('.entity-filters input[type="submit"]');
        const select = document.querySelector('.entity-filters select');
        return bio.width >= hero.width - 2 && hero.top >= header.bottom &&
          button.scrollHeight <= button.clientHeight + 1 &&
          getComputedStyle(select).backgroundRepeat === 'no-repeat' &&
          document.documentElement.scrollWidth <= innerWidth;
      })()
    JS
    select 'Comic issue', from: 'Media type'
    click_button 'Apply filters'
    expect(page).to have_text('No matching works')
    expect(page).to have_current_path(metadata_entity_path(entity), ignore_query: true)
  end

  it 'shows complete source labels in a desktop sidebar' do
    game = VideoGame.create!(title: 'Hades', external_url: 'https://store.steampowered.com/app/1145360/')
    page.current_window.resize_to(1440, 900)
    visit video_game_path(game)

    expect(page).to have_link('Search HowLongToBeat')
    expect(page.evaluate_script(<<~JS)).to be true
      [...document.querySelectorAll('.media-source-label')].every(label =>
        label.scrollWidth <= label.clientWidth && label.scrollHeight <= label.clientHeight)
    JS
  end

  it 'provides distinct mobile genre links with touch targets and keyboard navigation' do
    game = VideoGame.create!(title: 'Hades', metadata_details: { 'genres' => %w[Action Roguelike],
                                                                 'features' => ['Single-player'] })
    page.current_window.resize_to(390, 844)
    visit video_game_path(game)

    expect(page.evaluate_script(<<~JS)).to be true
      (() => {
        const link = document.querySelector('.media-description-tags a');
        const feature = document.querySelector('.category-pill-static');
        return link.getBoundingClientRect().height >= 44 &&
          getComputedStyle(link).color !== getComputedStyle(feature).color &&
          document.documentElement.scrollWidth <= innerWidth;
      })()
    JS
    find('a.category-pill', text: 'Roguelike').send_keys(:enter)
    expect(page).to have_css('h1', text: 'Roguelike')
    expect(page).to have_link('Hades')
  end

  it 'opens a single issue disclosure from the keyboard with an accessible touch target' do
    comic = Comic.create!(title: 'A series')
    issue = comic.comic_issues.create!(issue_number: 1, title: 'An issue',
                                       credits: [{ 'name' => 'Alex Ross', 'role' => 'Cover artist' }])
    page.current_window.resize_to(390, 844)
    visit comic_path(comic)

    toggle = find("#comic_issue_#{issue.id} .series-entry-toggle")
    expect(toggle.evaluate_script('this.getBoundingClientRect().height')).to be >= 44
    toggle.send_keys(:enter)
    expect(page).to have_css("#comic_issue_#{issue.id} .series-entry-details[open]")
    within "#comic_issue_#{issue.id}" do
      expect(page).to have_link('Alex Ross')
      expect(page).to have_no_css('details.series-entry-metadata')
    end
    toggle.send_keys(:enter)
    expect(page).to have_no_css("#comic_issue_#{issue.id} .series-entry-details[open]")
  end

  it 'keeps tablet episode titles readable beside progress and disclosure buttons' do
    user = create_and_login_user
    show = TvShow.create!(title: 'Severance')
    show.tv_episodes.create!(name: 'Good News About Hell', season: 1, episode: 1)
    LibraryItem.create!(user: user, item: show, is_collected: true)
    page.current_window.resize_to(768, 900)
    visit tv_show_path(show)

    expect(page).to have_link('1. Good News About Hell')
    expect(page.evaluate_script(<<~JS)).to be true
      (() => {
        const entry = document.querySelector('.series-entry');
        const row = entry.querySelector('.series-entry-row').getBoundingClientRect();
        const title = entry.querySelector('.series-entry-title').getBoundingClientRect();
        const progress = entry.querySelector('.series-entry-track').getBoundingClientRect();
        const toggle = entry.querySelector('.series-entry-toggle').getBoundingClientRect();
        return title.width > row.width * .4 && progress.right <= toggle.left;
      })()
    JS
  end
end
