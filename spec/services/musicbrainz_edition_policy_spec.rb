# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MusicBrainz release-group edition policy' do
  def payload(name)
    JSON.parse(Rails.root.join("spec/fixtures/album_metadata/#{name}.json").read)
  end

  def group_response(group)
    stub_request(:get, "https://musicbrainz.org/ws/2/release-group/#{group.fetch('id')}")
      .with(query: { fmt: 'json', inc: 'artist-credits+genres+releases' }).to_return(body: group.to_json)
  end

  def release_response(release)
    stub_request(:get, "https://musicbrainz.org/ws/2/release/#{release.fetch('id')}")
      .with(query: { fmt: 'json', inc: 'artist-credits+genres+recordings+artist-rels+recording-rels+work-rels+' \
                                       'work-level-rels+isrcs+labels' }).to_return(body: release.to_json)
  end

  it 'declines the captured Skeletal group instead of selecting its year-only five-track Bonus CD' do
    group = payload('skeletal_release_group')
    expect(group['releases']).to include(hash_including('title' => 'Skeletal Lamping Bonus CD', 'date' => '2008'))
    group_response(group)
    album = Album.create!(title: 'Skeletal Lamping', artist: 'of Montreal', api_id: "musicbrainz_#{group['id']}")
    expect(album.metadata_refresh.state).to eq('edition_required')
    expect(album.metadata_refresh.message).to include('verified release edition')
    expect(album.album_tracks).to be_empty
    expect(album.metadata_refresh.provider_values).not_to have_key('album_release_id')
    expect(WebMock).not_to have_requested(:get, %r{https://musicbrainz.org/ws/2/release/})
  end

  it 'does not resolve competing editions from order, title equality, dates or region' do
    group = payload('skeletal_release_group')
    album = Album.create!(title: 'Skeletal Lamping')
    album.update_columns(api_id: "musicbrainz_#{group['id']}")
    variants = [group['releases'], group['releases'].reverse,
                group['releases'].map do |row|
                  row.merge('title' => 'Skeletal Lamping', 'date' => '2008-01-01', 'country' => 'US')
                end]
    variants.each do |releases|
      group_response(group.merge('releases' => releases))
      adapter = MetadataProvider.new(album, revalidate: true)
      _, tracks = adapter.call
      expect(adapter.album_edition_required).to be(true)
      expect(adapter.partial).to be(true)
      expect(tracks).to be_empty
    end
    expect(WebMock).not_to have_requested(:get, %r{https://musicbrainz.org/ws/2/release/})
  end

  it 'retains the verified pin and existing IDs even when the group contains several editions' do
    group = payload('geese_release_group')
    release = payload('geese_official_release')
    group_response(group)
    release_response(release)
    album = Album.create!(title: '3D Country')
    AlbumMetadata.reconcile(album, AlbumMetadata.musicbrainz(release))
    original = album.album_tracks.order(:id).map(&:attributes)
    MetadataRefresh.create!(item: album, provider_values: {
                              'album_release_id' => release['id'], 'album_release_group_id' => group['id']
                            })
    album.update_columns(api_id: "musicbrainz_#{group['id']}")
    allow_any_instance_of(MetadataProvider).to receive(:sleep)
    adapter = MetadataProvider.new(album)
    _, tracks = adapter.call
    expect(adapter.album_edition_required).to be(false)
    expect(adapter.album_release_id).to eq(release['id'])
    expect(AlbumMetadata.reconcile(album, tracks)).to eq(0)
    expect(album.album_tracks.order(:id).map(&:attributes)).to eq(original)
  end

  it 'keeps explicit multi-disc releases fully supported without consulting a release group' do
    release = payload('geese_three_disc_release')
    release_response(release)
    album = Album.create!(title: '3D Country', api_id: release['id'],
                          external_url: "https://musicbrainz.org/release/#{release['id']}")
    expect(album.metadata_refresh.state).to eq('success')
    expect(album.album_tracks.group(:disc_number).count).to eq(1 => 11, 2 => 3, 3 => 9)
    expect(WebMock).not_to have_requested(:get, %r{https://musicbrainz.org/ws/2/release-group/})
  end

  it 'does not auto-select a sole release with unverified status' do
    group = payload('geese_release_group')
    group['releases'] = [group['releases'].first.merge('status' => nil)]
    group_response(group)
    album = Album.create!(title: '3D Country', api_id: "musicbrainz_#{group['id']}")
    expect(album.metadata_refresh.state).to eq('edition_required')
    expect(album.album_tracks).to be_empty
    expect(WebMock).not_to have_requested(:get, %r{https://musicbrainz.org/ws/2/release/})
  end
  it 'does not fetch competing 11- and 23-track editions to choose the largest list' do
    group = payload('geese_release_group')
    group_response(group)
    standard = release_response(payload('geese_official_release'))
    expanded = release_response(payload('geese_three_disc_release'))
    album = Album.create!(title: '3D Country', api_id: "musicbrainz_#{group['id']}")
    expect(album.metadata_refresh.state).to eq('edition_required')
    expect(album.album_tracks).to be_empty
    expect(standard).not_to have_been_requested
    expect(expanded).not_to have_been_requested
  end
end
