# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Artwork resets', type: :request do
  let(:user) { User.create!(name: 'Player', email: 'player@example.com', password: 'password123') }
  let(:game) { VideoGame.create!(title: 'Portal') }
  let!(:library) { LibraryItem.create!(user: user, item: game) }

  def attach_cover(attachment)
    attachment.attach(io: StringIO.new(File.binread(Rails.root.join('spec/fixtures/files/valid-cover.png'))),
                      filename: 'cover.png', content_type: 'image/png')
  end

  def sign_in
    post login_path, params: { session: { email: user.email, password: 'password123' } }
  end

  it 'resets only the personal cover and preserves shared artwork blobs and tracking' do
    sign_in
    attach_cover(game.cover_image)
    library.game_cover_image.attach(game.cover_image.blob)
    library.update!(review: 'My review', rating: '4.0')
    get video_game_path(game)
    expect(response.body).to include('Use default artwork')

    delete game_cover_path(video_game_id: game.id)
    expect(response).to redirect_to(video_game_path(game))
    expect(library.reload.game_cover_image).not_to be_attached
    expect(game.reload.cover_image).to be_attached
    expect(game.cover_image.blob.service.exist?(game.cover_image.blob.key)).to be(true)
    expect(library).to have_attributes(review: 'My review', rating: '4.0')
    expect(ApplicationController.helpers.game_library_cover(game, library)).to eq(game.stored_cover_url)

    get video_game_path(game)
    expect(response.body).not_to include('Use default artwork')
    delete game_cover_path(video_game_id: game.id)
    expect(response).to have_http_status(:see_other)
  end

  it 'requires login and a library entry to reset a personal cover' do
    attach_cover(library.game_cover_image)
    delete game_cover_path(video_game_id: game.id)
    expect(response).to redirect_to(login_path)
    sign_in
    another_game = VideoGame.create!(title: 'Other game')
    delete game_cover_path(video_game_id: another_game.id)
    expect(response).to have_http_status(:not_found)
    expect(library.reload.game_cover_image).to be_attached
  end

  it 'restores source artwork for catalog uploads without deleting reused blobs' do
    sign_in
    source = 'https://covers.openlibrary.org/b/id/123-M.jpg'
    stub_request(:get, source).to_return(body: File.binread(Rails.root.join('spec/fixtures/files/valid-cover.png')),
                                         headers: { 'Content-Type' => 'image/png' })
    movie = Movie.create!(title: 'Alien', thumbnail_url: source)
    LibraryItem.create!(user: user, item: movie)
    attach_cover(movie.cover_image)
    blob = movie.cover_image.blob
    get edit_movie_path(movie)
    expect(response.body).to include('Use default artwork', 'shared catalog')

    expect do
      delete media_cover_path(type: 'movie', id: movie.id)
    end.to have_enqueued_job(ImportMediaCoverJob).with(movie, movie.thumbnail_url)
    expect(response).to redirect_to(movie_path(movie))
    expect(movie.reload.cover_image).not_to be_attached
    expect(blob.service.exist?(blob.key)).to be(true)

    get media_cover_path(type: 'movie', id: movie.id)
    expect(response).to have_http_status(:found)
    expect(movie.reload.cover_image.blob.metadata['remote_source']).to eq(source)
    expect(movie.cover_image.blob_id).not_to eq(blob.id)
  end

  it 'uses the latest admin-selected artwork as the default while preserving a personal selection' do
    attach_cover(game.cover_image)
    library.game_cover_image.attach(game.cover_image.blob)
    personal_blob = library.game_cover_image.blob
    user.update!(admin: true)
    sign_in
    source = 'https://covers.openlibrary.org/b/id/456-M.jpg'
    stub_request(:get, source).to_return(body: File.binread(Rails.root.join('spec/fixtures/files/valid-cover.png')),
                                         headers: { 'Content-Type' => 'image/png' })

    post update_cover_art_admin_video_game_path(game), params: { thumbnail_url: source }
    expect(response).to have_http_status(:see_other)
    expect(game.reload.thumbnail_url).to eq(source)
    expect(library.reload.game_cover_image.blob_id).to eq(personal_blob.id)
    expect(personal_blob.service.exist?(personal_blob.key)).to be(true)

    user.update!(admin: false)
    delete game_cover_path(video_game_id: game.id)
    expect(library.reload.game_cover_image).not_to be_attached
    get media_cover_path(type: 'video_game', id: game.id)
    expect(game.reload.cover_image.blob.metadata['remote_source']).to eq(source)
    delete media_cover_path(type: 'video_game', id: game.id)
    expect(game.reload.cover_image.blob.metadata['remote_source']).to eq(source)
  end

  it 'restores admin-selected catalog artwork after a user uploads a custom catalog cover' do
    user.update!(admin: true)
    sign_in
    movie = Movie.create!(title: 'Alien')
    LibraryItem.create!(user: user, item: movie)
    source = 'https://covers.openlibrary.org/b/id/789-M.jpg'
    stub_request(:get, source).to_return(body: File.binread(Rails.root.join('spec/fixtures/files/valid-cover.png')),
                                         headers: { 'Content-Type' => 'image/png' })
    post update_cover_art_admin_movie_path(movie), params: { thumbnail_url: source }
    expect(response).to have_http_status(:see_other)
    user.update!(admin: false)
    patch movie_path(movie), params: { movie: { cover_image: fixture_file_upload('valid-cover.png', 'image/png') } }
    expect(response).to have_http_status(:found)

    delete media_cover_path(type: 'movie', id: movie.id)
    get media_cover_path(type: 'movie', id: movie.id)
    expect(movie.reload.thumbnail_url).to eq(source)
    expect(movie.cover_image.blob.metadata['remote_source']).to eq(source)
  end

  it 'does not remove downloaded default artwork or reset an item outside the users library' do
    sign_in
    attach_cover(game.cover_image)
    game.cover_image.blob.update!(metadata: { remote_source: 'https://example.com/default.png' })
    delete media_cover_path(type: 'video_game', id: game.id)
    expect(game.reload.cover_image).to be_attached

    movie = Movie.create!(title: 'Alien')
    attach_cover(movie.cover_image)
    delete media_cover_path(type: 'movie', id: movie.id)
    expect(response).to have_http_status(:not_found)
    expect(movie.reload.cover_image).to be_attached
    delete media_cover_path(type: 'user', id: user.id)
    expect(response).to have_http_status(:not_found)
  end
end
