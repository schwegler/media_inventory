# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlbumMetadata do
  let(:album) { Album.create!(title: '3D Country', artist: 'Geese', release_year: 2023, api_id: 'itunes_1677353916') }

  let(:eleven_tracks) do
    (1..11).map do |i|
      {
        'provider_id' => "itunes:1677353#{100 + i}",
        'title' => "Track #{i}",
        'disc_number' => 1,
        'track_number' => i,
        'duration_ms' => 180_000,
        'credits' => [{ 'name' => 'Geese', 'role' => 'Track artist', 'kind' => 'artist' }]
      }
    end
  end

  it 'imports all 11 tracks and maintains order' do
    changed = AlbumMetadata.reconcile(album, eleven_tracks)
    expect(changed).to eq(11)
    expect(album.album_tracks.count).to eq(11)

    sorted_track_numbers = album.album_tracks.order(:disc_number, :track_number).pluck(:track_number)
    expect(sorted_track_numbers).to eq((1..11).to_a)
  end

  it 'updates existing tracks in place during refresh without creating duplicates' do
    AlbumMetadata.reconcile(album, eleven_tracks)
    expect(album.album_tracks.count).to eq(11)

    # Subsequent refresh with same disc/track numbers but new provider IDs or titles
    refreshed_tracks = eleven_tracks.map do |t|
      t.merge('title' => "Refreshed #{t['title']}")
    end

    changed = AlbumMetadata.reconcile(album, refreshed_tracks)
    expect(album.album_tracks.count).to eq(11)
    expect(album.album_tracks.first.title).to start_with('Refreshed')
  end
end
