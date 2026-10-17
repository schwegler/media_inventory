# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'TV Shows and Episodes Management', type: :system do
  let!(:user) do
    User.create(
      name: 'TV Watcher',
      email: 'watcher@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end

  it 'enables me to create a tv show, review it, and manage its episodes' do
    # Log in
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
    expect(page).to have_text('Logged in successfully')

    # Create TV Show
    visit new_tv_show_path
    expect(page).to have_css('[data-connected="true"]') unless Capybara.current_driver == :rack_test
    fill_in 'Title', with: 'Breaking Bad'
    click_add_manually

    expect(page).to have_field('tv_show[network]', visible: true)

    fill_in 'tv_show[network]', with: 'AMC'
    check 'In Collection'
    select '★★★★★', from: 'tv_show[rating]'
    fill_in 'tv_show[review]', with: 'Simply amazing.'
    click_button 'Create TV Show'

    expect(page).to have_text('Breaking Bad')
    expect(page).to have_link('AMC')
    expect(page).to have_text('Simply amazing.')

    # Pre-create an episode so it displays on the show page
    tv_show = TvShow.last
    episode = tv_show.tv_episodes.create!(
      name: 'Pilot',
      season: 1,
      episode: 1,
      summary: 'Walter White begins his chemistry journey.'
    )

    # Reload show page to see the episode
    visit tv_show_path(tv_show)
    expect(page).to have_link('1. Pilot')
    find("#tv_episode_#{episode.id} .series-entry-toggle").click
    expect(page).to have_text('Walter White begins his chemistry journey.')

    within "#tv_episode_#{episode.id}" do
      click_link 'Write review'
    end
    within '.review-drawer-form' do
      fill_in 'Your review (optional)', with: 'Great introduction episode!'
      select '5.0 ★', from: 'Rating'
      click_button 'Save review'
    end

    expect(page).to have_text('Review updated.')
    within "#tv_episode_#{episode.id}" do
      click_button 'Mark watched'
      expect(page).to have_button('✓ Watched · Undo')
    end
    find("#tv_episode_#{episode.id} .series-entry-toggle").click
    expect(page).to have_text('Great introduction episode!')

    within "#tv_episode_#{episode.id}" do
      click_button 'Undo'
      expect(page).to have_button('Mark watched')
    end

    # Edit the catalog and personal entry through the current edit surface.
    visit edit_tv_show_path(TvShow.find_by!(title: 'Breaking Bad'))
    select '4.0 ★', from: 'tv_show[rating]'
    fill_in 'tv_show[review]', with: 'Overrated but still good.'
    click_button 'Save changes'

    expect(page).to have_text('Tv show was successfully updated.')
    visit tv_show_path(TvShow.last)
    expect(page).to have_text('Overrated but still good.')

    find('.library-management summary').click

    # Delete TV Show
    if Capybara.current_driver == :rack_test
      click_button 'Delete from Library'
    else
      accept_confirm do
        click_button 'Delete from Library'
      end
    end
    expect(page).to have_text('Tv show was successfully removed from your library.')
  end

  it 'displays a list of TV shows' do
    show = TvShow.find_or_create_by!(title: 'The Wire', network: 'HBO')
    LibraryItem.create!(item: show, user: user)

    visit tv_shows_path

    expect(page).to have_text('The Wire')
  end

  it 'keeps the selected season after a Turbo refresh and page reload' do
    skip 'Requires JavaScript' if Capybara.current_driver == :rack_test

    show = TvShow.create!(title: 'Season selection')
    [1, 3].each do |season|
      show.tv_episodes.create!(name: "Season #{season} premiere", season: season, episode: 1)
    end

    visit tv_show_path(show)
    expect(page).to have_css('[data-controller="series-navigation"][data-connected="true"]')
    select 'Season 3', from: 'Season'
    expect(page).to have_select('Season', selected: 'Season 3')
    expect(page).to have_css('#series-entries .series-entry-title', text: 'Season 3 premiere')
    expect(page).to have_no_css('#series-entries .series-entry-title', text: 'Season 1 premiere')

    page.execute_script(<<~JS)
      document.addEventListener('turbo:morph', () => {
        document.body.dataset.seasonTestMorphed = 'true'
      }, { once: true })
      window.Turbo.visit(window.location.href, { action: "replace" })
    JS
    expect(page).to have_css('body[data-season-test-morphed="true"]')
    expect(page).to have_select('Season', selected: 'Season 3')
    page.refresh
    expect(page).to have_select('Season', selected: 'Season 3')
    expect(page).to have_css('#series-entries .series-entry-title', text: 'Season 3 premiere')
    expect(page).to have_no_css('#series-entries .series-entry-title', text: 'Season 1 premiere')

    click_button 'Previous season'
    expect(page).to have_select('Season', selected: 'Season 1')
    page.refresh
    expect(page).to have_select('Season', selected: 'Season 1')
  end
end
