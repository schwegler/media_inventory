# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Video Games Management', type: :system do
  let!(:user) do
    User.create(
      name: 'Game Player',
      email: 'player@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end

  it 'enables me to create, edit, and delete a video game' do
    # Log in
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
    expect(page).to have_text('Logged in successfully')

    # Create Video Game
    visit new_video_game_path
    fill_in 'Title', with: 'The Legend of Zelda'
    click_button 'Add Manually'
    fill_in 'Developer', with: 'Nintendo'
    fill_in 'Publisher', with: 'Nintendo'
    fill_in 'Platform', with: 'Nintendo Switch'
    fill_in 'Release year', with: '2017'
    select '★★★★★', from: 'Rating'
    fill_in 'Review', with: 'An absolute masterpiece.'
    click_button 'Create Video Game'

    expect(page).to have_text('The Legend of Zelda')
    expect(page).to have_text('Nintendo')
    expect(page).to have_text('An absolute masterpiece.')

    # Edit Video Game via inline form
    select '★★★★', from: 'video_game[rating]'
    fill_in 'video_game[review]', with: 'Great exploration game!'
    click_button 'Save Review & Playing Status'

    expect(page).to have_text('Video game was successfully updated.')
    expect(page).to have_text('Great exploration game!')

    # Delete Video Game
    click_button 'Delete from Library'

    expect(page).to have_text('Video game was successfully deleted.')
  end

  it 'displays a list of video games' do
    VideoGame.create!(title: 'Portal 2', developer: 'Valve', user: user)

    visit video_games_path

    expect(page).to have_text('Portal 2')
  end
end
