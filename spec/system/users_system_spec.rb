# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Users Profile and Directory Management', type: :system do
  let!(:user) do
    User.create!(
      name: 'Normal User',
      email: 'normal@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end

  let!(:admin) do
    User.create!(
      name: 'Admin User',
      email: 'admin@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current,
      admin: true
    )
  end

  it 'allows a user to view and update their profile' do
    # Log in as normal user
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
    expect(page).to have_text('Logged in successfully')

    # Go to profile
    visit user_path(user)
    expect(page).to have_text('NORMAL USER')

    # Edit profile
    visit edit_user_path(user)
    fill_in 'Name', with: 'Updated Normal User'
    fill_in 'Bluesky Handle', with: 'normal.bsky.social'
    fill_in 'New Password (optional)', with: ''
    fill_in 'Confirmation', with: ''
    submit_form_button 'Save changes'

    expect(page).to have_text('Profile updated')
    expect(page).to have_text('UPDATED NORMAL USER')
  end

  it 'allows an admin to delete a user' do
    # Log in as admin
    visit login_path
    fill_in 'Email', with: admin.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
    expect(page).to have_text('Logged in successfully')

    # Go to members directory
    visit users_path
    expect(page).to have_text('Normal User')
    expect(page).to have_text('Delete')

    # Delete normal user
    if Capybara.current_driver == :rack_test
      click_button 'Delete'
    else
      accept_confirm do
        click_button 'Delete'
      end
    end

    expect(page).to have_text('User deleted')
    expect(page).not_to have_text('Normal User')
  end
end
