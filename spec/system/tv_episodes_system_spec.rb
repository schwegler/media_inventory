# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'TV Episodes Management', type: :system do
  let!(:user) do
    User.create!(
      name: 'Show Watcher',
      email: 'watcher@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end

  let!(:tv_show) do
    TvShow.create!(
      title: 'Breaking Bad',
      network: 'AMC',
      user: user
    )
  end

  let!(:tv_episode) do
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

    # Go to TV show show page
    visit tv_show_path(tv_show)
    expect(page).to have_text('Breaking Bad')
    expect(page).to have_text('Ep 1: Pilot')

    # Click on the episode link to visit the episode show page
    click_link 'Ep 1: Pilot'

    # Verify we are on the episode page
    expect(page).to have_text('Pilot')
    expect(page).to have_text('Season 1 Episode 1 of Breaking Bad')
    expect(page).to have_text('Walter White begins his chemistry journey.')
    expect(page).to have_text('Not Watched')

    # Rate and review the episode
    select '★★★★★', from: 'tv_episode[rating]'
    fill_in 'tv_episode[review]', with: 'The start of something legendary!'
    click_button 'Save Episode Status'

    # Verify expected results on page load
    expect(page).to have_text('✓ Watched')
    expect(page).to have_text('The start of something legendary!')
    expect(page).to have_text('★★★★★')

    # Click "Mark Unwatched"
    click_button '📁 Mark Unwatched'

    # Verify state reverted to unwatched
    expect(page).to have_text('Not Watched')
    expect(page).not_to have_text('✓ Watched')

    # Navigate back to the TV show page
    click_link '← Back to Breaking Bad'
    expect(page).to have_current_path(tv_show_path(tv_show))
    expect(page).to have_text('Breaking Bad')
  end

  it 'prompts guest users to log in' do
    visit tv_episode_path(tv_episode)

    expect(page).to have_text('Log in to log your progress for this episode.')
    expect(page).to have_link('Log in', href: login_path)
  end
end
