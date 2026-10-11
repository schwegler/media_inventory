# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Editing details while adding an item preserves artwork and avoids API re-searching', type: :system do
  let!(:user) { create_and_login_user(email: 'artwork-preserve@example.com') }
  let(:png) { File.binread(Rails.root.join('spec/fixtures/files/valid-cover.png')) }

  before do
    stub_request(:get, %r{https://image\.tmdb\.org/}).to_return(body: png, headers: { 'Content-Type' => 'image/png' })
    stub_request(:get, %r{https://shared\.fastly\.steamstatic\.com/}).to_return(body: png, headers: { 'Content-Type' => 'image/png' })
    stub_request(:get, %r{https://is1-ssl\.mzstatic\.com/}).to_return(body: png, headers: { 'Content-Type' => 'image/png' })
  end

  it 'preserves chosen artwork and metadata when editing movie details' do
    selected_art = 'https://image.tmdb.org/t/p/w500/matrix_selected_cover.jpg'
    movie = Movie.create!(
      title: 'The Matrix',
      director: 'The Wachowskis',
      release_year: 1999,
      thumbnail_url: selected_art
    )

    visit new_movie_path
    expect(page).to have_css('[data-connected="true"]')

    fill_in 'Title', with: 'The Matrix'
    expect(page).to have_css('.thumbnail-option-card', text: 'The Matrix')

    find('.thumbnail-option-card', text: 'The Matrix').click
    expect(page).to have_text('Log Details')

    # Verify initial artwork preview and hidden field
    thumbnail_field = find('input[name="movie[thumbnail_url]"]', visible: :all)
    expect(thumbnail_field.value).to eq(selected_art)
    expect(page).to have_css("img.thumbnail-preview-img[src*='/media/covers/movie/#{movie.id}']")

    # Edit the director and other fields in the details stage
    fill_in 'movie[director]', with: 'Lana Wachowski, Lilly Wachowski'
    fill_in 'movie[genre]', with: 'Sci-Fi'

    # The artwork should remain untouched!
    expect(thumbnail_field.value).to eq(selected_art)
    expect(page).to have_css("img.thumbnail-preview-img[src*='/media/covers/movie/#{movie.id}']")

    click_button 'Create Movie'
    expect(page).to have_text('Movie was successfully logged.')

    created_movie = Movie.order(:created_at).last
    expect(created_movie.director).to eq('Lana Wachowski, Lilly Wachowski')
    expect(created_movie.thumbnail_url).to eq(selected_art)
  end

  it 'preserves chosen artwork and does not wipe game fields when editing video game details' do
    selected_art = 'https://shared.fastly.steamstatic.com/elden_ring_header.jpg'
    allow(MediaSearchService).to receive(:call).and_return([
      {
        title: 'Elden Ring',
        developer: 'FromSoftware',
        publisher: 'Bandai Namco',
        platform: 'PC, PS5, Xbox Series X',
        release_year: 2022,
        thumbnail_url: selected_art,
        api_id: 'steam_1245620',
        source: 'Steam'
      }
    ])

    visit new_video_game_path
    expect(page).to have_css('[data-connected="true"]')

    fill_in 'Title', with: 'Elden Ring'
    expect(page).to have_css('.thumbnail-option-card', text: 'Elden Ring')

    find('.thumbnail-option-card', text: 'Elden Ring').click
    expect(page).to have_text('Log Details')

    thumbnail_field = find('input[name="video_game[thumbnail_url]"]', visible: :all)
    initial_thumbnail = thumbnail_field.value
    expect(initial_thumbnail).to be_present
    expect(page).to have_css("img.thumbnail-preview-img[src='#{initial_thumbnail}']")
    expect(find_field('video_game[developer]').value).to eq('FromSoftware')

    # Edit developer and publisher
    fill_in 'video_game[developer]', with: 'FromSoftware, Inc.'
    fill_in 'video_game[publisher]', with: 'Bandai Namco Entertainment'

    # Verify artwork and metadata are NOT wiped out or changed
    expect(thumbnail_field.value).to eq(initial_thumbnail)
    expect(page).to have_css("img.thumbnail-preview-img[src='#{initial_thumbnail}']")
    expect(find('input[name="video_game[api_id]"]', visible: :all).value).to eq('steam_1245620')

    click_button 'Create Video Game'
    expect(page).to have_text('Video game was successfully logged.')

    created_game = VideoGame.order(:created_at).last
    expect(created_game.developer).to eq('FromSoftware, Inc.')
    expect(created_game.publisher).to eq('Bandai Namco Entertainment')
    expect(created_game.thumbnail_url).to eq(initial_thumbnail)
  end

  it 'preserves chosen artwork when editing album artist and year' do
    selected_art = 'https://is1-ssl.mzstatic.com/image/thumb/Music/abbey_road.jpg/500x500bb.jpg'
    album = Album.create!(
      title: 'Abbey Road',
      artist: 'The Beatles',
      release_year: 1969,
      genre: 'Rock',
      thumbnail_url: selected_art
    )

    visit new_album_path
    expect(page).to have_css('[data-connected="true"]')

    fill_in 'Title', with: 'Abbey Road'
    expect(page).to have_css('.thumbnail-option-card', text: 'Abbey Road')

    find('.thumbnail-option-card', text: 'Abbey Road').click
    expect(page).to have_text('Log Details')

    thumbnail_field = find('input[name="album[thumbnail_url]"]', visible: :all)
    expect(thumbnail_field.value).to eq(selected_art)
    expect(page).to have_css("img.thumbnail-preview-img[src*='/media/covers/album/#{album.id}']")

    # Edit the artist in details stage
    fill_in 'album[artist]', with: 'The Beatles (2019 Mix)'

    # Artwork remains untouched
    expect(thumbnail_field.value).to eq(selected_art)
    expect(page).to have_css("img.thumbnail-preview-img[src*='/media/covers/album/#{album.id}']")

    click_button 'Create Album'
    expect(page).to have_text('Album was successfully logged.')

    created_album = Album.order(:created_at).last
    expect(created_album.artist).to eq('The Beatles (2019 Mix)')
    expect(created_album.thumbnail_url).to eq(selected_art)
  end
end
