# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Landing and Authentication', type: :system do
  let!(:user) do
    User.create(
      name: 'Active Tracker',
      email: 'tracker@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end

  it 'displays the community landing page for guests' do
    visit root_path

    expect(page).to have_text('Community Activity')
    expect(page).to have_text('Welcome to MediaTracker')
    expect(page).to have_text('Active Trackers')
    expect(page).to have_text('Active Tracker')
  end

  it 'allows a user to sign up' do
    visit signup_path

    within '.auth-tab-content[data-tab-name="email"]' do
      fill_in 'Name', with: 'New User'
      fill_in 'Email', with: 'newuser@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Confirmation', with: 'password123'
      click_button 'Sign up'
    end

    expect(page).to have_text('Welcome to MediaTracker!')
    expect(page).to have_text('NEW USER')
  end

  it 'fails login with invalid credentials' do
    visit login_path

    fill_in 'Email', with: 'tracker@example.com'
    fill_in 'Password', with: 'wrongpassword'
    click_button 'Log in'

    expect(page).to have_text('Invalid email/password combination')
  end

  it 'logs in successfully, displays dashboard, and logs out' do
    # Log in
    visit login_path
    fill_in 'Email', with: 'tracker@example.com'
    fill_in 'Password', with: 'password123'
    click_button 'Log in'

    expect(page).to have_text('Logged in successfully')
    expect(page).to have_text('ACTIVE TRACKER')

    # Visit dashboard (root)
    visit root_path
    expect(page).to have_text('Welcome back, Active Tracker')

    # Log out
    if Capybara.current_driver == :rack_test
      find('form.dropdown-logout-form button', visible: :all).click
    else
      find('.nav-user-info').click
      click_button 'Sign Out'
    end
    # Confirm we are logged out
    visit root_path
    expect(page).to have_text('Community Activity')
  end

  it 'renders the landing page dashboard successfully when there are activities with TvEpisodes' do
    # Create another user to make it a friend activity
    friend = User.create!(
      name: 'Friend User',
      email: 'friend@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )

    # Create TV Show and Episode
    tv_show = TvShow.find_or_create_by!(title: '30 Rock')
    episode = tv_show.tv_episodes.create!(
      name: 'The Aftermath',
      season: 1,
      episode: 2
    )
    lib_item = LibraryItem.create!(
      user: friend,
      item: episode,
      consumed: true,
      rating: '4.5',
      review: 'Hilarious episode'
    )

    # Create activity for the episode
    Activity.create!(
      user: friend,
      trackable: lib_item,
      activity_type: 'reviewed'
    )

    # Log in
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
    expect(page).to have_text('Logged in successfully')

    # Visit dashboard (root)
    visit root_path

    # Verify dashboard loads successfully and displays the friend's activity
    expect(page).to have_text('Welcome back, Active Tracker')
    expect(page).to have_text('NEW FROM FRIENDS')
    expect(page).to have_text('POPULAR WITH FRIENDS')
    expect(page).to have_text('POPULAR REVIEWS WITH FRIENDS')
    expect(page).to have_text('Hilarious episode')
  end

  it 'allows a user to sign up via Bluesky App Password and then log in with it' do
    # 1. Sign up
    visit signup_path
    find('button', text: 'Bluesky (App Password)').click

    within '.auth-tab-content[data-tab-name="bsky-app"]' do
      fill_in 'Name', with: 'Bluesky App User'
      fill_in 'Bluesky Handle', with: 'bskyuser.bsky.social'
      fill_in 'App Password', with: 'xxxx-xxxx-xxxx-xxxx'
      click_button 'Sign up with App Password'
    end

    expect(page).to have_text('Welcome to MediaTracker!')
    expect(page).to have_text('BLUESKY APP USER')

    # Log out
    if Capybara.current_driver == :rack_test
      find('form.dropdown-logout-form button', visible: :all).click
    else
      find('.nav-user-info').click
      click_button 'Sign Out'
    end

    # 2. Log in
    visit login_path
    find('button', text: 'Bluesky (App Password)').click

    within '.auth-tab-content[data-tab-name="bsky-app"]' do
      fill_in 'Bluesky Handle', with: 'bskyuser.bsky.social'
      fill_in 'App Password', with: 'xxxx-xxxx-xxxx-xxxx'
      click_button 'Log in with App Password'
    end

    expect(page).to have_text('Logged in successfully via Bluesky App Password.')
    expect(page).to have_text('BLUESKY APP USER')
  end
end
