# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Album tracks through signed imports', type: :request do
  let(:user) do
    User.create!(name: 'Listener', email: 'tracks@example.com', password: 'password', confirmed_at: Time.current)
  end

  it 'imports once despite a recent request and preserves curated catalog and library fields on duplicate import' do
    post login_path, params: { session: { email: user.email, password: 'password' } }
    user.update!(metadata_requested_at: Time.current)
    payload = Rails.root.join('spec/fixtures/album_metadata/magazine_itunes.json').read
    lookup = stub_request(:get, 'https://itunes.apple.com/lookup')
             .with(query: { id: '21296483', entity: 'song', limit: '200' }).to_return(body: payload)
    allow(RefreshMediaMetadataJob).to receive(:perform_later).and_return(false)
    selection = MetadataImport.sign('album', title: 'Magazine', api_id: 'itunes_21296483', artist: 'Jump, Little Children')
    post albums_path, params: { album: { import_selection: selection, review: 'Personal review', rating: '4' } }
    album = Album.last
    expect(response).to redirect_to(album)
    expect(album.album_tracks.count).to eq(11)
    expect(album.metadata_refresh.state).to eq('success')
    album.update!(title: 'Curated title')
    track = album.album_tracks.first
    track.update!(title: 'Curated track')
    history = user.library_items.find_by!(item: album).attributes
    post albums_path, params: { album: { import_selection: selection } }
    expect(Album.where(api_id: 'itunes_21296483').count).to eq(1)
    expect(album.reload.title).to eq('Curated title')
    expect(track.reload.title).to eq('Curated track')
    expect(user.library_items.find_by!(item: album).attributes).to eq(history)
    expect(lookup).to have_been_requested.once
    expect(RefreshMediaMetadataJob).not_to have_received(:perform_later)
  end
end
