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
    fill_in 'tv_show[network]', with: 'AMC'
    check 'In Collection'
    select '★★★★★', from: 'tv_show[rating]'
    fill_in 'tv_show[review]', with: 'Simply amazing.'
    click_button 'Create TV Show'

    expect(page).to have_text('Breaking Bad')
    expect(page).to have_text('on AMC')
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
    expect(page).to have_text('Ep 1: Pilot')
    expect(page).to have_text('Walter White begins his chemistry journey.')

    # Mark episode as watched
    within "#tv_episode_#{episode.id}" do
      fill_in 'tv_episode[review]', with: 'Great introduction episode!'
      select '★★★★★', from: 'tv_episode[rating]'
      click_button 'Watch'
    end

    expect(page).to have_text('✓ Watched')
    expect(page).to have_text('Great introduction episode!')

    # Toggle watch back (Unwatch)
    click_button 'Unwatch'
    expect(page).to have_text('Not Watched')

    # Edit TV Show via inline form
    select '★★★★', from: 'tv_show[rating]'
    fill_in 'tv_show[review]', with: 'Overrated but still good.'
    click_button 'Save Review & Watching Status'

    expect(page).to have_text('Tv show was successfully updated.')
    expect(page).to have_text('Overrated but still good.')

    # Delete TV Show
    if Capybara.current_driver == :rack_test
      click_button 'Delete from Library'
    else
      accept_confirm do
        click_button 'Delete from Library'
      end
    end
    expect(page).to have_text('Tv show was successfully deleted.')
  end

  it 'displays a list of TV shows' do
    show = TvShow.find_or_create_by!(title: 'The Wire', network: 'HBO')
    LibraryItem.create!(item: show, user: user)

    visit tv_shows_path

    expect(page).to have_text('The Wire')
  end
end
