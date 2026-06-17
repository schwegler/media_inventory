# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Movies Management', type: :system do
  let!(:user) do
    User.create(name: 'Movie Buff', email: 'movie@example.com', password: 'password123',
                password_confirmation: 'password123', confirmed_at: Time.current)
  end

  it 'enables me to create a movie' do
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
    expect(page).to have_text('Logged in successfully')

    visit new_movie_path
    expect(page).to have_css('[data-connected="true"]') unless Capybara.current_driver == :rack_test
    fill_in 'Title', with: 'Inception'
    click_add_manually

    expect(page).to have_field('Director', visible: true)

    fill_in 'Director', with: 'Christopher Nolan'
    fill_in 'Release year', with: '2010'
    select '★★★★★', from: 'Rating'
    click_button 'Create Movie'

    expect(page).to have_text('Inception')
    expect(page).to have_text('Directed by Christopher Nolan')
  end
end
