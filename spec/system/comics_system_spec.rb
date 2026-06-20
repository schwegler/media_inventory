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
    expect(page).to have_css('[data-connected="true"]') unless Capybara.current_driver == :rack_test
    fill_in 'Title', with: 'Watchmen'
    click_add_manually

    expect(page).to have_field('comic[issue_number]', visible: true)

    fill_in 'comic[issue_number]', with: '1'
    fill_in 'comic[publisher]', with: 'DC Comics'
    fill_in 'comic[writer]', with: 'Alan Moore'
    fill_in 'comic[artist]', with: 'Dave Gibbons'
    check 'In Collection'
    select '★★★★★', from: 'comic[rating]'
    fill_in 'comic[review]', with: 'Who watches the watchmen?'
    click_button 'Create Comic'

    begin
      expect(page).to have_text('Comic was successfully logged.')
    rescue StandardError => e
      validity = begin
        page.evaluate_script("document.querySelector('form.standard-form').checkValidity()")
      rescue StandardError
        'ERROR'
      end
      puts "FORM VALIDITY: #{validity}"
      raise e
    end
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
    if Capybara.current_driver == :rack_test
      click_button 'Delete from Library'
    else
      accept_confirm do
        click_button 'Delete from Library'
      end
    end

    expect(page).to have_text('Comic was successfully removed from your library.')
  end

  it 'displays a list of comics' do
    comic = Comic.find_or_create_by!(title: 'Spider-Man', writer: 'Stan Lee')
    LibraryItem.create!(item: comic, user: user)

    visit comics_path

    expect(page).to have_text('Spider-Man')
  end
end
