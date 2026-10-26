# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metadata entity graph' do
  def credit(name, role, **extra)
    { 'name' => name, 'role' => role, 'kind' => 'person' }.merge(extra.stringify_keys)
  end

  it 'uses one person across roles and media, preserving punctuation' do
    movie = Movie.create!(title: 'Film', director: 'Jane Doe', writer: 'Jane Doe')
    comic = Comic.create!(title: 'Comic', writer: 'Jane Doe')
    expect(movie.metadata_entities.pluck(:id).uniq).to eq(comic.metadata_entities.pluck(:id))
    expect(MetadataEntity.where(name: 'Jane Doe').count).to eq(1)
    album = Album.create!(title: 'Album', metadata_credits_data: [credit('AC/DC', 'Album artist')])
    expect(album.metadata_entities.pluck(:name)).to eq(['AC/DC'])
  end

  it 'prefers exact external identities and keeps same-name distinct provider IDs separate' do
    first = MetadataEntityResolver.call(credit('John Smith', 'Actor', provider: 'TMDB:contributor', external_id: '1'))
    second = MetadataEntityResolver.call(credit('John Smith', 'Writer', provider: 'TMDB:contributor', external_id: '2'))
    renamed = MetadataEntityResolver.call(credit('J. Smith', 'Director', provider: 'TMDB:contributor', external_id: '1'))
    expect(first).not_to eq(second)
    expect(renamed).to eq(first)
    expect(first.to_param).not_to eq(second.to_param)
  end

  it 'upgrades an unbound legacy person with provider identifiers and aliases' do
    movie = Movie.create!(title: 'Film', director: 'Jane Doe')
    entity = movie.metadata_entities.first
    movie.update!(metadata_credits_data: [credit('Jane Doe', 'Director', provider: 'TMDB:contributor', external_id: '1',
                                                                         aliases: ['J. Doe'])])
    expect(movie.metadata_credits.count).to eq(1)
    expect(movie.metadata_entities.first).to eq(entity)
    expect(entity.reload.aliases).to include('J. Doe')
  end

  it 'reconciles changed roles and names without duplicates or stale legacy links' do
    movie = Movie.create!(title: 'Film', director: 'Old Director')
    movie.update!(director: 'New Director')
    2.times { MetadataEntitySync.call(movie) }
    expect(movie.metadata_entities.pluck(:name)).to eq(['New Director'])
    expect(MetadataSearch.call(Movie.all, 'Old Director')).to be_empty
  end

  it 'backfills locally, idempotently, with no provider requests or lost legacy values' do
    movie = Movie.create!(title: 'Film', director: 'Jane Doe')
    movie.metadata_credits.destroy_all
    2.times { movie.with_lock { MetadataEntitySync.call(movie) } }
    expect(movie.metadata_credits.count).to eq(1)
    expect(movie.reload.director).to eq('Jane Doe')
    expect(WebMock).not_to have_requested(:get, /themoviedb/)
  end

  it 'keeps actual issue credits separate and searches containing series' do
    comic = Comic.create!(title: 'Batman')
    first = comic.comic_issues.create!(issue_number: 1, credits: [credit('Alex Ross', 'Cover artist')])
    second = comic.comic_issues.create!(issue_number: 2, credits: [credit('Alan Moore', 'Writer')])
    expect(comic.metadata_credits.count).to eq(0)
    expect(MetadataSearch.call(ComicIssue.all, 'Alex Ross')).to eq([first])
    expect(MetadataSearch.call(ComicIssue.all, 'Alan Moore')).to eq([second])
    expect(MetadataSearch.call(Comic.all, 'Alex Ross')).to eq([comic])
  end

  it 'preserves episode-level credits and surfaces only the containing show' do
    show = TvShow.create!(title: 'Example Show')
    episode = show.tv_episodes.create!(name: 'Pilot', season: 1, episode: 1,
                                       credits: [credit('Pilot Writer', 'Writer')])
    show.tv_episodes.create!(name: 'Finale', season: 1, episode: 2)
    expect(MetadataSearch.call(TvEpisode.all, 'Pilot Writer')).to eq([episode])
    expect(MetadataSearch.call(TvShow.all, 'Pilot Writer')).to eq([show])
    expect(show.metadata_credits.count).to eq(0)
  end

  it 'ranks exact and partial titles above metadata, escapes wildcards, and returns albums once' do
    album = Album.create!(title: '1989', artist: 'Taylor Swift', metadata_credits_data: [
                            credit('Taylor Swift', 'Album artist'), credit('Taylor Swift', 'Producer')
                          ])
    exact = Album.create!(title: 'Taylor Swift', artist: 'Other')
    prefix = Album.create!(title: 'Taylor Swift Live', artist: 'Other')
    expect(MetadataSearch.call(Album.all, 'Taylor Swift').to_a).to eq([exact, prefix, album])
    expect(MetadataSearch.call(Album.all, 'Taylor Swift').page(1).per(2).total_count).to eq(3)
    expect(MetadataSearch.call(Album.all, '%')).to be_empty
    expect(MetadataSearch.call(Movie.all, 'Taylor Swift')).to be_empty
  end

  it 'searches aliases, track titles and featured credits without assigning them to the album' do
    album = Album.create!(title: 'Compilation')
    track = album.album_tracks.create!(title: 'Hidden Song', provider_id: 'provider:1', credits: [
                                         credit('Featured Artist', 'Featured artist', aliases: ['Stage Name'])
                                       ])
    expect(MetadataSearch.call(Album.all, 'Hidden Song')).to eq([album])
    expect(MetadataSearch.call(Album.all, 'Stage Name')).to eq([album])
    expect(MetadataSearch.call(AlbumTrack.all, 'Featured Artist')).to eq([track])
    expect(album.metadata_credits).to be_empty
    expect(MetadataMatchContext.call([album], 'Stage Name')[album.id]).to include('Hidden Song', 'Featured Artist')
  end

  it 'ingests only supplied iTunes tracks and preserves IDs, numbers, duration and content flags' do
    album = Album.create!(title: 'Album')
    album.update_columns(api_id: 'itunes_42')
    rows = [{ wrapperType: 'collection', collectionId: 42, collectionName: 'Album',
              artistName: 'Main Artist', artistId: 7 },
            { wrapperType: 'track', kind: 'song', collectionId: 42, trackId: 9, trackName: 'Song',
              artistName: 'Guest Artist', artistId: 8,
              discNumber: 2, trackNumber: 3, trackTimeMillis: 187_000, trackExplicitness: 'explicit' }]
    stub_request(:get, 'https://itunes.apple.com/lookup').with(query: hash_including({ id: '42', entity: 'song' }))
                                                         .to_return(body: { results: rows }.to_json)
    fields, tracks = MetadataProvider.new(album).call
    album.update!(fields.except(:thumbnail_url))
    2.times { AlbumMetadata.reconcile(album, tracks) }
    expect(album.album_tracks.count).to eq(1)
    expect(album.album_tracks.first).to have_attributes(disc_number: 2, track_number: 3, duration_ms: 187_000,
                                                        content_rating: 'explicit')
    expect(MetadataSearch.call(Album.all, 'Guest Artist')).to eq([album])
  end

  it 'harvests full TMDB credits and organizations from an already-fetched payload' do
    data = { 'credits' => { 'cast' => [{ 'id' => 1, 'name' => 'Actor', 'character' => 'Hero' }],
                            'crew' => [{ 'id' => 2, 'name' => 'Composer', 'job' => 'Original Music Composer' },
                                       { 'id' => 3, 'name' => 'Camera', 'job' => 'Director of Photography' }] },
             'production_companies' => [{ 'id' => 24, 'name' => 'A24' }],
             'belongs_to_collection' => { 'id' => 4, 'name' => 'Franchise' } }
    rows = ProviderEntityMetadata.tmdb(data)
    movie = Movie.create!(title: 'Film', metadata_credits_data: rows)
    expect(movie.metadata_credits.pluck(:role)).to include('Actor', 'Composer', 'Cinematographer',
                                                           'Production company', 'Collection')
    expect(MetadataSearch.call(Movie.all, 'A24')).to eq([movie])
  end

  it 'keeps every supplied comic role and provider ID distinct' do
    rows = [{ 'id' => 12, 'name' => 'Creator', 'role' => 'writer, penciler, inker, colorist, letterer, cover, editor' }]
    credits = ProviderEntityMetadata.comic(rows)
    expect(credits.map { |entry| entry['role'] }).to eq(['Writer', 'Penciler', 'Inker', 'Colorist', 'Letterer',
                                                         'Cover artist', 'Editor'])
    expect(credits.map { |entry| entry['external_id'] }.uniq).to eq(['12'])
  end

  it 'extracts MusicBrainz recordings, artist relations and ISRC from supplied release media' do
    producer = { 'type' => 'producer', 'artist' => { 'id' => 'p', 'name' => 'Producer', 'type' => 'Person' } }
    recording = { 'length' => 120_000, 'isrcs' => ['ISRC1'], 'relations' => [producer] }
    data = { 'media' => [{ 'position' => 1, 'tracks' => [{ 'id' => 'track-id', 'position' => 2,
                                                           'title' => 'Song', 'recording' => recording }] }] }
    track = AlbumMetadata.musicbrainz(data).first
    expect(track).to include('title' => 'Song', 'duration_ms' => 120_000, 'isrc' => 'ISRC1')
    expect(track['credits']).to include(a_hash_including('name' => 'Producer', 'role' => 'Producer'))
  end

  it 'preserves entity relationships and tracks through admin media merges' do
    source = Album.create!(title: 'Source', artist: 'Artist')
    target = Album.create!(title: 'Target')
    track = source.album_tracks.create!(title: 'Song', provider_id: 'provider:1')
    Admin::MergeMedia.call(source, target)
    expect(track.reload.album).to eq(target)
    expect(MetadataSearch.call(Album.all, 'Artist')).to eq([target])
  end
  it 'keeps legacy actor/director browsing working while stored metadata is being backfilled' do
    movie = Movie.create!(title: 'Older Film', director: 'Original Director', actors: 'Original Actor')
    movie.metadata_credits.destroy_all
    expect(Category.list_for('directors').map(&:name)).to include('Original Director')
    expect(Category.items_for('directors', 'Original Director')).to eq([movie])
    expect(Category.items_for('actors', 'Original Actor')).to eq([movie])
  end

  it 'keeps separate TMDB company/network IDs and canonical multi-role artist credits' do
    rows = ProviderEntityMetadata.tmdb({ 'networks' => [{ 'id' => 1, 'name' => 'Network' }],
                                         'production_companies' => [{ 'id' => 1, 'name' => 'Company' }] })
    show = TvShow.create!(title: 'Example', metadata_credits_data: rows)
    expect(show.metadata_entities.pluck(:name)).to contain_exactly('Network', 'Company')
    album = Album.create!(title: 'Artist Record', artist: 'Jane Doe')
    movie = Movie.create!(title: 'Composer Film', metadata_credits_data: [{ 'name' => 'Jane Doe', 'role' => 'Composer' }])
    expect(album.metadata_entities.first).to eq(movie.metadata_entities.first)
  end
end
