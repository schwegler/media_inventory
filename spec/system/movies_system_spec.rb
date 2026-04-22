# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Movies Management', type: :system do
  let!(:user) do
    User.create(name: 'Example User', email: 'user@example.com', confirmed_at: Time.current)
  end

  before do
    driven_by(:rack_test)
  end

  it 'enables me to create a movie' do
    visit login_path
    fill_in 'Email', with: user.email
    click_button 'Log in'

    user.reload
    # Email is hidden on verify_otp page, so we don't fill it
    fill_in 'One-Time Password', with: user.login_token
    click_button 'Verify'

    visit new_movie_path

    fill_in 'Title', with: 'Inception'
    fill_in 'Director', with: 'Christopher Nolan'
    fill_in 'Release year', with: '2010'
    fill_in 'Rating', with: '5'

    click_button 'Create Movie'

    expect(page).to have_text('Inception')
    expect(page).to have_text('Director: Christopher Nolan')
  end

  it 'displays a list of movies' do
    Movie.create!(title: 'The Matrix', director: 'Wachowskis')

    visit movies_path

    expect(page).to have_text('The Matrix')
  end
end
