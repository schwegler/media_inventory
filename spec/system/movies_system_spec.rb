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

    expect(page).to have_field('movie[director]', visible: true)

    fill_in 'movie[director]', with: 'Christopher Nolan'
    fill_in 'movie[release_year]', with: '2010'
    select '★★★★★', from: 'movie[rating]'
    click_button 'Create Movie'

    expect(page).to have_text('Inception')
    expect(page).to have_text('Directed by Christopher Nolan')

    # Test the like button
    expect(page).to have_button('Like')
    click_button 'Like'
    expect(page).to have_css('.likes-count', text: '1')
  end
end
