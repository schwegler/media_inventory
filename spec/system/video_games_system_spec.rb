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
    expect(page).to have_css('[data-connected="true"]') unless Capybara.current_driver == :rack_test
    fill_in 'Title', with: 'The Legend of Zelda'
    click_add_manually
    fill_in 'video_game[developer]', with: 'Nintendo'
    fill_in 'video_game[publisher]', with: 'Nintendo'
    fill_in 'video_game[platform]', with: 'Nintendo Switch'
    fill_in 'video_game[release_year]', with: '2017'
    check 'In Collection'
    select '★★★★★', from: 'video_game[rating]'
    fill_in 'video_game[review]', with: 'An absolute masterpiece.'
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
    if Capybara.current_driver == :rack_test
      click_button 'Delete from Library'
    else
      accept_confirm do
        click_button 'Delete from Library'
      end
    end

    expect(page).to have_text('Video game was successfully removed from your library.')
  end

  it 'displays a list of video games' do
    game = VideoGame.find_or_create_by!(title: 'Portal 2', developer: 'Valve')
    LibraryItem.create!(item: game, user: user)

    visit video_games_path

    expect(page).to have_text('Portal 2')
  end
end
