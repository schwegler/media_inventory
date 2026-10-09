# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Typed and responsive artwork', type: :request do
  include ActiveJob::TestHelper

  let(:user) { User.create!(name: 'Player', email: 'player@example.com', password: 'password123') }
  let(:other) { User.create!(name: 'Other', email: 'other@example.com', password: 'password123') }
  let(:game) { VideoGame.create!(title: 'Portal') }
  let!(:library) { LibraryItem.create!(user: user, item: game) }

  before { post login_path, params: { session: { email: user.email, password: 'password123' } } }

  it 'stores private typed uploads locally and excludes them from another members detail page' do
    file = fixture_file_upload('valid-cover.png', 'image/png')
    post upload_game_artwork_path(video_game_id: game.id),
         params: { artwork: { kind: 'logo', image: file, edition: 'My private edition' } }
    expect(response).to have_http_status(:see_other)
    art = library.game_artworks.last
    expect(art.image.blob.content_type).to eq('image/webp')
    get video_game_path(game)
    expect(response.body).to include('My private edition', 'data-artwork-kind="logo"')
    post login_path, params: { session: { email: other.email, password: 'password123' } }
    get video_game_path(game)
    expect(response.body).not_to include('My private edition', 'data-artwork-kind="logo"')
    delete delete_game_artwork_path(video_game_id: game.id, id: art.id)
    expect(response).to have_http_status(:not_found)
    expect(art.reload).to be_present
  end

  it 'requires signed derivative URLs and falls back to original pixels while regenerating a missing file' do
    io = StringIO.new(File.binread(Rails.root.join('spec/fixtures/files/landscape-cover.png')))
    source = ActiveStorage::Blob.create_and_upload!(io: io,
                                                    filename: 'original.png', content_type: 'image/png')
    MediaArtworkRendition.request(source)
    perform_enqueued_jobs(only: GenerateMediaArtworkRenditionJob)
    row = source.artwork_renditions.first
    get artwork_rendition_path(row.id)
    expect(response).to have_http_status(:not_found)
    row.blob.service.delete(row.blob.key)
    token = row.signed_id(purpose: 'artwork-rendition')
    expect { get artwork_rendition_path(token) }.to have_enqueued_job(GenerateMediaArtworkRenditionJob).with(row)
    expect(response).to redirect_to(rails_storage_proxy_path(source))
    expect { get artwork_rendition_path(token) }.not_to have_enqueued_job(GenerateMediaArtworkRenditionJob)
    perform_enqueued_jobs(only: GenerateMediaArtworkRenditionJob)
    get artwork_rendition_path(token)
    expect(response).to redirect_to(rails_storage_proxy_path(row.reload.blob))
  end
end
