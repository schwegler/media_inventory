# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Comics Management', type: :system do
  let!(:user) do
    User.create(
      name: 'Comic Reader',
      email: 'reader@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end

  it 'enables me to create, edit, and delete a comic' do
    # Log in
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
    expect(page).to have_text('Logged in successfully')

    # Create Comic
    visit new_comic_path
    fill_in 'Title', with: 'Watchmen'
    click_button 'Add Manually'
    fill_in 'Issue number', with: '1'
    fill_in 'Publisher', with: 'DC Comics'
    fill_in 'Writer', with: 'Alan Moore'
    fill_in 'Artist', with: 'Dave Gibbons'
    select '★★★★★', from: 'Rating'
    fill_in 'Review', with: 'Who watches the watchmen?'
    click_button 'Create Comic'

    expect(page).to have_text('Watchmen')
    expect(page).to have_text('by Alan Moore')
    expect(page).to have_text('Who watches the watchmen?')

    # Edit Comic via inline form
    select '★★★★', from: 'comic[rating]'
    fill_in 'comic[review]', with: 'Masterpiece of graphic novels!'
    click_button 'Save Review & Reading Status'

    expect(page).to have_text('Comic was successfully updated.')
    expect(page).to have_text('Masterpiece of graphic novels!')

    # Delete Comic
    click_button 'Delete from Library'

    expect(page).to have_text('Comic was successfully deleted.')
  end

  it 'displays a list of comics' do
    Comic.create!(title: 'Spider-Man', writer: 'Stan Lee', user: user)

    visit comics_path

    expect(page).to have_text('Spider-Man')
  end
end
