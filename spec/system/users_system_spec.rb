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
    fill_in 'New Password (optional)', with: ''
    fill_in 'Confirmation', with: ''
    click_button 'Save changes'

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
      click_button 'Delete account'
    else
      accept_confirm do
        click_button 'Delete account'
      end
    end

    expect(page).to have_text('User deleted')
    expect(page).not_to have_text('Normal User')
  end

  it 'keeps member profile links usable beside administrative deletion at narrow widths' do
    visit login_path
    fill_in 'Email', with: admin.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
    expect(page).to have_text('Logged in successfully')
    page.current_window.resize_to(320, 844)
    visit users_path
    card = find('.member-card', text: user.name)
    within(card) do
      expect(page).to have_button('Delete account')
      click_link "View #{user.name}'s profile"
    end
    expect(page).to have_current_path(user_path(user))
    expect(page).to have_text("#{user.name}’s library")
    expect(User.exists?(user.id)).to be true
    expect_profile_actions_aligned
    page.current_window.resize_to(1440, 900)
    expect_profile_actions_aligned
    click_button 'Follow'
    expect(page).to have_button('Unfollow')
    expect(admin.reload.following?(user)).to be true
    expect_profile_actions_aligned
  end

  def expect_profile_actions_aligned
    sizes = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.library-profile-actions .btn, .library-profile-actions .sleek-btn')].map(el => {
        const rect = el.getBoundingClientRect(); return { top: rect.top, left: rect.left, width: rect.width, height: rect.height }
      })
    JS
    expect(sizes.size).to eq(2)
    dimension = sizes.map { |size| size['top'].round }.uniq.size > 1 ? 'left' : 'top'
    expect(sizes.map { |size| size[dimension].round }.uniq.size).to eq(1)
    expect(sizes.map { |size| size['height'].round }.uniq.size).to eq(1)
  end
end
