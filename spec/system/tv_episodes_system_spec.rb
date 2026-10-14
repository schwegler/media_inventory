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

  let!(:tv_show) { TvShow.create!(title: 'Breaking Bad') }
  let!(:library_item) { LibraryItem.create!(item: tv_show, user: user, is_collected: true) }
  let!(:episode) do
    tv_show.tv_episodes.create!(
      name: 'Pilot',
      season: 1,
      episode: 1,
      summary: 'Start.'
    )
  end

  it 'enables me to navigate to an episode page, rate/review it, and toggle watched state' do
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
    expect(page).to have_text('Logged in successfully')

    visit tv_episode_path(episode)
    expect(page).to have_text('Season 1, episode 1 of Breaking Bad')

    click_link 'Write review'
    within '.review-drawer-form' do
      fill_in 'Your review (optional)', with: 'Great start.'
      select '5.0 ★', from: 'Rating'
      click_button 'Save review'
    end

    expect(page).to have_text('Review updated.')
    expect(page).to have_text('Great start.')
    click_button 'Mark watched'
    expect(page).to have_text('✓ Watched')

    click_button 'Mark unwatched'
    expect(page).to have_text('Not Watched')
  end

  it 'prompts guest users to log in' do
    visit tv_episode_path(episode)
    expect(page).to have_text('Log in to track your progress.')
  end
end
