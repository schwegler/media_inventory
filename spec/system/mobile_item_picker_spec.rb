# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Mobile API item picker', type: :system do
  after do
    page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride')
  rescue StandardError
    nil
  end

  before do
    create_and_login_user(email: 'mobile-picker@example.com')
    page.current_window.resize_to(390, 844)
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride',
                                    width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
  end

  it 'renders readable list cards, touch cues, and no horizontal overflow on mobile' do
    Movie.create!(
      title: 'Inception',
      director: 'Christopher Nolan',
      release_year: 2010
    )

    visit new_movie_path
    expect(page).to have_css('[data-connected="true"]')
    expect(page).to have_text('Log Movie')

    fill_in 'Title', with: 'Inception'
    find_field('Title').send_keys(:enter)

    expect(page).to have_css('.thumbnail-option-card', text: 'Inception')
    expect(page).to have_css('.option-title', text: 'Inception')
    expect(page).to have_css('.option-details', text: /2010.*Christopher Nolan/)
    expect(page).to have_css('.option-badge', text: /local/i)
    expect(page).to have_css('.option-select-cue', text: 'Select')

    # Verify no horizontal scroll / overflow on phone viewport
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)

    # Tap the card to select and advance to Stage 2 (Details)
    find('.thumbnail-option-card', text: 'Inception').click

    expect(page).to have_text('Log Details')
    expect(page).to have_field('movie[title]', with: /Inception/, visible: :all)
    expect(page).to have_field('Director', with: 'Christopher Nolan')
    expect(page).to have_field('Release year', with: '2010')

    # Back button returns to search stage on mobile
    click_button '← BACK'
    expect(page).to have_text('Log Movie')
    expect(page).to have_button('Add Manually')

    # Add Manually button advances to manual form
    click_button 'Add Manually'
    expect(page).to have_text('Log Details')
  end

  it 'renders readable album cards on mobile with artist and year' do
    Album.create!(
      title: 'Abbey Road',
      artist: 'The Beatles',
      release_year: 1969
    )

    visit new_album_path
    expect(page).to have_css('[data-connected="true"]')

    fill_in 'Title', with: 'Abbey Road'
    find_field('Title').send_keys(:enter)

    expect(page).to have_css('.thumbnail-option-card', text: 'Abbey Road')
    expect(page).to have_css('.option-title', text: 'Abbey Road')
    expect(page).to have_css('.option-details', text: /1969.*The Beatles/)
    expect(page).to have_css('.option-select-cue', text: 'Select')

    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)

    find('.thumbnail-option-card', text: 'Abbey Road').click

    expect(page).to have_text('Log Details')
    expect(page).to have_field('Artist', with: 'The Beatles')
  end
end
