# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Albums Management', type: :system do
  let!(:user) do
    User.create(
      name: 'Album Collector',
      email: 'collector@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end

  it 'enables me to create, edit, and delete an album' do
    # Log in
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
    expect(page).to have_text('Logged in successfully')

    # Create Album
    visit new_album_path
    expect(page).to have_css('[data-connected="true"]') unless Capybara.current_driver == :rack_test
    fill_in 'Title', with: 'Abbey Road'
    click_add_manually
    fill_in 'album[artist]', with: 'The Beatles'
    fill_in 'album[release_year]', with: '1969'
    fill_in 'album[genre]', with: 'Rock'
    check 'In Collection'
    select '★★★★★', from: 'album[rating]'
    fill_in 'album[review]', with: 'A classic masterpiece.'
    click_button 'Create Album'

    expect(page).to have_text('Abbey Road')
    expect(page).to have_text('The Beatles')
    expect(page).to have_text('A classic masterpiece.')

    # Edit Album via inline form on the show page
    select '★★★★', from: 'album[rating]'
    fill_in 'album[review]', with: 'Classic Rock masterpiece!'
    click_button 'Save Review & Listening Status'

    expect(page).to have_text('Album was successfully updated.')
    expect(page).to have_text('Classic Rock masterpiece!')

    # Delete Album
    if Capybara.current_driver == :rack_test
      click_button 'Delete from Library'
    else
      accept_confirm do
        click_button 'Delete from Library'
      end
    end

    expect(page).to have_text('Album was successfully removed from your library.')
  end

  it 'displays a list of albums' do
    album = Album.find_or_create_by!(title: 'Dark Side of the Moon', artist: 'Pink Floyd')
    LibraryItem.create!(item: album, user: user)

    visit albums_path

    expect(page).to have_text('Dark Side of the Moon')
    expect(page).to have_text('Pink Floyd')
  end
end
