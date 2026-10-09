# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Media source picker', type: :system do
  include ActiveJob::TestHelper

  it 'selects Steam artwork, saves it in app storage, and renders that local cover' do
    png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aO1sAAAAASUVORK5CYII=')
    image_url = 'https://shared.fastly.steamstatic.com/portal-test.png'
    stub_request(:get,
                 /storesearch/).to_return(body: { items: [{ id: 620, name: 'Portal 2', tiny_image: image_url }] }.to_json)
    stub_request(:get, /appdetails/).to_return(body: { '620' => { success: true, data: {
      name: 'Portal 2', developers: ['Valve'], header_image: image_url, release_date: { date: 'Apr 18 2011' }
    } } }.to_json)
    stub_request(:get, image_url).to_return(body: png, headers: { 'Content-Type' => 'image/png' })
    create_and_login_user(email: 'picker@example.com')
    expect(page).to have_text('Logged in successfully')
    visit new_video_game_path
    expect(page).to have_css('[data-connected="true"]')
    fill_in 'Title', with: 'Portal'
    expect(page).to have_css('.thumbnail-option-card', text: 'Portal 2')
    expect(page).to have_css('.option-badge', text: /steam/i)
    find('.thumbnail-option-card', text: 'Portal 2').click
    expect(page).to have_field('video_game[title]', with: 'Portal 2 (2011)', visible: :all)
    perform_enqueued_jobs do
      click_button 'Create Video Game'
      expect(page).to have_text('Video game was successfully logged.')
    end
    expect(page).to have_text('Portal 2')
    expect(page).to have_css('img[src*="/media/covers/"]')
    expect(page).not_to have_css('img[src="https://shared.fastly.steamstatic.com/portal-test.png"]')
    saved_game = VideoGame.find_by!(api_id: 'steam_620')
    expect(saved_game.cover_image).to be_attached
    expect(saved_game.release_year).to eq(2011)
    expect(page.title).to include('Portal 2')
  end

  it 'loads a legacy movie cover on mobile without a background import or manual backfill' do
    page.current_window.resize_to(390, 844)
    source = 'https://covers.openlibrary.org/b/id/123-M.jpg'
    png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aO1sAAAAASUVORK5CYII=')
    stub_request(:get, source).to_return(body: png, headers: { 'Content-Type' => 'image/png' })
    movie = Movie.create!(title: 'Legacy movie cover')
    movie.update_columns(thumbnail_url: source)
    expect(movie.cover_image).not_to be_attached
    visit movie_path(movie)
    expect(page.title).to include('Legacy movie cover')
    expect(page).to have_css('.show-poster img[src*="/media/covers/"]')
    loaded = page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      const img = document.querySelector('.show-poster img')
      if (img.complete) done(img.naturalWidth > 0)
      else {
        img.addEventListener('load', () => done(img.naturalWidth > 0), { once: true })
        img.addEventListener('error', () => done(false), { once: true })
      }
    JS
    expect(loaded).to be(true)
    expect(movie.reload.cover_image).to be_attached
    expect(WebMock).to have_requested(:get, source).once
  end
end
