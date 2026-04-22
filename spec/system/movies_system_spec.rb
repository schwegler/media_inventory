# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Movies Management', type: :system do
  let!(:user) do
    User.create(name: 'Example User', email: 'user@example.com', password: 'password',
                password_confirmation: 'password')
  end

  before do
    driven_by(:rack_test)
  end

  it 'enables me to create a movie' do
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: user.password
    click_button 'Log in'

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
