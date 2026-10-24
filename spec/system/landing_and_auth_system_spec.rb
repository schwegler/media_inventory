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

    expect(page).to have_text('A shelf for everything you love.')
    expect(page).not_to have_text('Community Activity')
    find('summary', text: 'From the community').click
    expect(page).to have_text('Community Activity')
    expect(page).to have_text('People in Trove')
    expect(page).to have_text('Active Tracker')
    find('summary', text: 'From the community').click

    [390, 720, 1440].each do |width|
      resize_browser_viewport(width, 1000)
      hero = find('.home-hero-mascot')
      copy = find('.home-hero-copy')
      expect(hero.find('img')['naturalWidth'].to_i).to be_positive
      if width <= 760
        expect(hero.rect.y).to be >= copy.rect.y + copy.rect.height
      else
        expect(hero.rect.x).to be >= copy.rect.x + copy.rect.width
      end
      expect(page).to have_link('Read taco ’bout it', href: 'https://tacobout.online/')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
      capture_ui_screenshot("landing-mascots-#{width}")
    end
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

    expect(page).to have_text('Welcome to Trove!')
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
    expect(page).to have_text('Continue your story')

    # Log out
    if Capybara.current_driver == :rack_test
      first('form.dropdown-logout-form button', visible: :all).click
    else
      find('.nav-user-info').click
      click_button 'Sign Out'
    end
    # Wait for the Turbo logout response before issuing another navigation.
    expect(page).to have_link('Log in', exact: true)
    expect(page).to have_text('A shelf for everything you love.')
    visit root_path
    expect(page).to have_text('A shelf for everything you love.')
    find('summary', text: 'From the community').click
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

    user.follow(friend)

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
      review: 'Hilarious episode',
      is_public: true
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
    expect(page).to have_text('Continue your story')
    expect(page).to have_text('New from friends')
    expect(page).to have_text('Popular with friends')
    expect(page).to have_text('Recent reviews from friends')
    expect(page).to have_text('Hilarious episode')
  end
end
