# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'TV Episodes Management', type: :system do
  let!(:user) do
    User.create(
      name: 'Show Watcher',
      email: 'watcher@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end

  let!(:tv_show) { TvShow.create!(title: 'Breaking Bad', user: user) }
  let!(:episode) do
    tv_show.tv_episodes.create!(
      name: 'Pilot',
      season: 1,
      episode: 1,
      summary: 'Walter White begins his chemistry journey.'
    )
  end

  it 'enables me to navigate to an episode page, rate/review it, toggle watched state, and navigate back' do
    # Log in
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
    expect(page).to have_text('Logged in successfully')

    # Navigate to show page
    visit tv_show_path(tv_show)
    click_link 'Ep 1: Pilot'

    expect(page).to have_text('Season 1 Episode 1 of Breaking Bad')

    # Mark as watched with rating/review
    fill_in 'tv_episode[review]', with: 'Mind-blowing start.'
    select '★★★★★', from: 'tv_episode[rating]'
    click_button 'Watch'

    expect(page).to have_text('✓ Watched')
    expect(page).to have_text('Mind-blowing start.')

    # Toggle watched state back (unwatch)
    click_button 'Unwatch'
    expect(page).to have_text('Not Watched')

    # Navigate back to show
    click_link 'Back to Breaking Bad'
    expect(page).to have_current_path(tv_show_path(tv_show))
  end

  it 'prompts guest users to log in' do
    visit tv_episode_path(episode)
    expect(page).to have_text('Please log in.')
    expect(page).to have_current_path(login_path)
  end
end
