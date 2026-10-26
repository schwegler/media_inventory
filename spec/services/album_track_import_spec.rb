# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Album track imports' do
  let(:user) { User.create!(name: 'Listener', email: 'album-import@example.com', password: 'password') }

  def fixture(name)
    JSON.parse(Rails.root.join("spec/fixtures/album_metadata/#{name}.json").read)
  end

  def itunes_payload(count: 2)
    album = { 'wrapperType' => 'collection', 'collectionId' => 42, 'trackCount' => count, 'artistName' => 'Artist' }
    tracks = (1..count).map do |number|
      { 'wrapperType' => 'track', 'kind' => 'song', 'collectionId' => 42,
        'trackId' => 100 + number, 'trackName' => "Song #{number}", 'discNumber' => 1,
        'trackNumber' => number, 'trackTimeMillis' => 180_000 }
    end
    { results: [album] + tracks }
  end

  def itunes_response(payload = itunes_payload)
    stub_request(:get, 'https://itunes.apple.com/lookup')
      .with(query: { id: '42', entity: 'song', limit: '200' }).to_return(body: payload.to_json)
  end

  def mb_response(type, id, payload)
    inc = if type == 'release-group'
            'artist-credits+genres+releases'
          else
            'artist-credits+genres+recordings+artist-rels+recording-rels+work-rels+work-level-rels+isrcs+labels'
          end
    stub_request(:get, "https://musicbrainz.org/ws/2/#{type}/#{id}")
      .with(query: { fmt: 'json', inc: inc }).to_return(body: payload.to_json)
  end

  it 'imports tracks at creation without depending on a queue or a user cooldown' do
    request = itunes_response
    allow(RefreshMediaMetadataJob).to receive(:perform_later).and_return(false)
    user.update!(metadata_requested_at: Time.current)
    album = Album.create!(title: 'Album', api_id: 'itunes_42')
    expect(album.album_tracks.order(:track_number).pluck(:title)).to eq(['Song 1', 'Song 2'])
    expect(album.metadata_refresh.state).to eq('success')
    expect(RefreshMediaMetadataJob).not_to have_received(:perform_later)
    album.update!(genre: 'Rock')
    expect(request).to have_been_requested.once
  end

  it 'records transient failure and safely retries without duplicating tracks' do
    request = stub_request(:get, 'https://itunes.apple.com/lookup')
              .with(query: { id: '42', entity: 'song', limit: '200' })
              .to_return(status: 503).then.to_return(body: itunes_payload.to_json)
    album = Album.create!(title: 'Album', api_id: '42')
    expect(album.metadata_refresh.state).to eq('unavailable')
    expect(album.album_tracks).to be_empty
    album.metadata_refresh.update!(requested_at: nil)
    expect(MetadataRefresher.new(album, user).enqueue).to eq('success')
    ids = album.album_tracks.pluck(:id)
    album.metadata_refresh.update!(requested_at: nil)
    user.update!(metadata_requested_at: nil)
    expect(MetadataRefresher.new(album, user).enqueue).to eq('unchanged')
    expect(album.album_tracks.pluck(:id)).to eq(ids)
    expect(request).to have_been_requested.times(3)
  end

  it 'marks missing and truncated iTunes data partial without clearing good tracks or edits' do
    payload = itunes_payload
    itunes_response(payload)
    album = Album.create!(title: 'Album', api_id: 'itunes_42')
    track = album.album_tracks.first
    track.update!(title: 'Personal title', duration_ms: 123, track_number: 8)
    original = album.album_tracks.order(:id).map(&:attributes)
    payload[:results] = payload[:results].take(2)
    itunes_response(payload)
    expect(MetadataRefresher.new(album, user).call(claimed: true)).to eq('partial')
    expect(album.album_tracks.order(:id).map(&:attributes)).to eq(original)
    itunes_response(results: [])
    expect(MetadataRefresher.new(album, user).call(claimed: true)).to eq('unavailable')
    expect(album.album_tracks.order(:id).map(&:attributes)).to eq(original)
  end

  it 'does not claim success when counts, numbering or track identities are unknown' do
    payload = itunes_payload
    payload[:results].first.delete('trackCount')
    payload[:results].last.delete('trackNumber')
    itunes_response(payload)
    album = Album.create!(title: 'Album', api_id: 'itunes_42')
    expect(album.metadata_refresh.state).to eq('partial')
  end

  it 'keeps an explicit multi-disc MusicBrainz edition and disc-local numbering' do
    release = fixture('geese_three_disc_release')
    mb_response('release', release.fetch('id'), release)
    album = Album.create!(title: '3D Country', api_id: "musicbrainz_#{release['id']}",
                          external_url: "https://musicbrainz.org/release/#{release['id']}")
    expect(album.album_tracks.group(:disc_number).count).to eq(1 => 11, 2 => 3, 3 => 9)
    expect(album.album_tracks.where(disc_number: 2).order(:track_number).pluck(:track_number)).to eq([1, 2, 3])
    expect(album.metadata_refresh.state).to eq('success')
  end

  it 'resolves a release group to a full official release and pins it across retries' do
    group = fixture('geese_release_group')
    release = fixture('geese_official_release')
    group_request = mb_response('release-group', group.fetch('id'), group)
    release_request = mb_response('release', release.fetch('id'), release)
    allow_any_instance_of(MetadataProvider).to receive(:sleep)
    album = Album.create!(title: '3D Country', api_id: "musicbrainz_#{group['id']}")
    expect(album.album_tracks.count).to eq(11)
    expect(album.metadata_refresh.provider_values['album_release_id']).to eq(release['id'])
    group['releases'] = [fixture('geese_three_disc_release')]
    mb_response('release-group', group.fetch('id'), group)
    expect(MetadataRefresher.new(album, user).call(claimed: true)).to eq('unchanged')
    expect(album.album_tracks.count).to eq(11)
    expect(group_request).to have_been_requested.times(2)
    expect(release_request).to have_been_requested.times(2)
  end

  it 'reports MusicBrainz media without full track rows as partial' do
    release = fixture('geese_three_disc_release')
    release['media'].first['tracks'] = release['media'].first['tracks'].take(2)
    mb_response('release', release.fetch('id'), release)
    album = Album.create!(title: '3D Country', api_id: release['id'],
                          external_url: "https://musicbrainz.org/release/#{release['id']}")
    expect(album.metadata_refresh.state).to eq('partial')
  end

  it 'leaves an existing edition untouched when a different edition is returned' do
    itunes_response
    album = Album.create!(title: 'Album', api_id: 'itunes_42')
    tracks = album.album_tracks.order(:id).map(&:attributes)
    payload = itunes_payload
    payload[:results].last['trackId'] = 999
    itunes_response(payload)
    expect(MetadataRefresher.new(album, user).call(claimed: true)).to eq('edition_conflict')
    expect(album.album_tracks.order(:id).map(&:attributes)).to eq(tracks)
  end

  it 'does not misidentify another collection or a search response as a track lookup' do
    payload = itunes_payload
    payload[:results].first['collectionId'] = 99
    itunes_response(payload)
    album = Album.create!(title: 'Album', api_id: 'itunes_42')
    expect(album.metadata_refresh.state).to eq('unavailable')
    expect(album.album_tracks).to be_empty
  end
  it 'excludes the Geese single from album search before selecting a provider ID' do
    stub_request(:get, 'https://musicbrainz.org/ws/2/release-group')
      .with(query: { query: '3D Country Geese', fmt: 'json' })
      .to_return(body: fixture('geese_search').to_json)
    results = MediaSearchService.new('3D Country Geese', 'album').send(:fetch_musicbrainz_albums, '3D Country Geese')
    expect(results.map { |row| row[:api_id] }).to eq(['musicbrainz_d87d8f5d-4d89-45e1-b86d-2f9241db0edc'])
  end

  it 'imports a signed shelf selection once and leaves library history intact on retry' do
    itunes_response
    data = { title: 'Album', api_id: 'itunes_42', external_url: 'https://music.apple.com/us/album/album/42' }
           .with_indifferent_access
    album = ShelfCatalogImport.call(Album, data)
    expect(album.album_tracks.count).to eq(2)
    track = album.album_tracks.first
    history = LibraryItem.create!(user: user, item: album, review: 'My review', rating: 4,
                                  consumed: true, consumed_at: Date.new(2023, 7, 1))
    track_history = LibraryItem.create!(user: user, item: track, review: 'Track review', rating: 5)
    original = [history.attributes, track_history.attributes]
    track.update!(title: 'Curated title', duration_ms: 155_000)
    again = ShelfCatalogImport.call(Album, data)
    expect(again.id).to eq(album.id)
    expect(MetadataRefresher.new(again, user).call(claimed: true)).to eq('unchanged')
    expect(track.reload).to have_attributes(title: 'Curated title', duration_ms: 155_000)
    expect([history.reload.attributes, track_history.reload.attributes]).to eq(original)
    expect(Album.where(api_id: 'itunes_42').count).to eq(1)
  end

  it 'retains a retryable state after a timeout rather than claiming complete tracks' do
    stub_request(:get, 'https://itunes.apple.com/lookup')
      .with(query: { id: '42', entity: 'song', limit: '200' }).to_timeout
    album = Album.create!(title: 'Album', api_id: 'itunes_42')
    expect(album.metadata_refresh.state).to eq('failed')
    expect(album.album_tracks).to be_empty
    itunes_response
    expect(MetadataRefresher.new(album, user).call(claimed: true)).to eq('success')
    expect(album.album_tracks.count).to eq(2)
  end

  it 'retrieves all 11 tracks from the public Magazine source payload' do
    stub_request(:get, 'https://itunes.apple.com/lookup')
      .with(query: { id: '21296483', entity: 'song', limit: '200' })
      .to_return(body: fixture('magazine_itunes').to_json)
    album = Album.create!(title: 'Magazine', api_id: 'itunes_21296483')
    expect(album.album_tracks.count).to eq(11)
    expect(album.metadata_refresh.state).to eq('success')
  end
  it 'reports a group without releases as partial and a throttled lookup as retryable' do
    group = fixture('geese_release_group')
    group.delete('releases')
    mb_response('release-group', group.fetch('id'), group)
    album = Album.create!(title: '3D Country', api_id: "musicbrainz_#{group['id']}")
    expect(album.metadata_refresh.state).to eq('partial')
    expect(album.album_tracks).to be_empty
    stub_request(:get, 'https://itunes.apple.com/lookup')
      .with(query: { id: '42', entity: 'song', limit: '200' }).to_return(status: 429)
    other = Album.create!(title: 'Unavailable', api_id: 'itunes_42')
    expect(other.metadata_refresh.state).to eq('rate_limited')
    expect(other.album_tracks).to be_empty
  end

  it 'marks the iTunes 200-song cap partial without inventing missing tracks' do
    payload = itunes_payload(count: 200)
    payload[:results].first['trackCount'] = 201
    itunes_response(payload)
    album = Album.create!(title: 'Large album')
    album.update_columns(api_id: 'itunes_42')
    adapter = MetadataProvider.new(album)
    _, rows = adapter.call
    expect(rows.size).to eq(200)
    expect(adapter.partial).to be(true)
  end

  it 'demonstrates that the historical Geese record matches a single, not the album edition' do
    tracks = AlbumMetadata.musicbrainz(fixture('geese_single_release'))
    expect(tracks.map { |row| row['title'] }).to eq(['3D Country', 'Cowboy Nudes'])
    expect(AlbumMetadata.musicbrainz(fixture('geese_official_release')).size).to eq(11)
  end
  it 'does not reuse an edition pin after the stored release-group identity changes' do
    group = fixture('geese_release_group')
    release = fixture('geese_official_release')
    mb_response('release-group', group.fetch('id'), group)
    mb_response('release', release.fetch('id'), release)
    allow_any_instance_of(MetadataProvider).to receive(:sleep)
    album = Album.create!(title: '3D Country', api_id: "musicbrainz_#{group['id']}")
    single_group = fixture('geese_search').fetch('release-groups').first
    single = fixture('geese_single_release')
    mb_response('release-group', single_group.fetch('id'), single_group)
    mb_response('release', single.fetch('id'), single)
    album.update_columns(api_id: "musicbrainz_#{single_group['id']}")
    adapter = MetadataProvider.new(album)
    _, rows = adapter.call
    expect(adapter.album_release_id).to eq(single['id'])
    expect(rows.size).to eq(2)
    original = album.album_tracks.order(:id).map(&:attributes)
    expect(MetadataRefresher.new(album, user).call(claimed: true)).to eq('edition_conflict')
    expect(album.album_tracks.order(:id).map(&:attributes)).to eq(original)
  end
end
