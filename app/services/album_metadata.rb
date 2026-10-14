# frozen_string_literal: true

class AlbumMetadata
  def self.itunes(rows)
    Array(rows).select { |row| row['wrapperType'] == 'track' && row['kind'] == 'song' }.filter_map do |row|
      next if row['trackId'].blank? || row['trackName'].blank?

      { 'provider_id' => "itunes:#{row['trackId']}", 'title' => row['trackName'],
        'disc_number' => row['discNumber'], 'track_number' => row['trackNumber'],
        'duration_ms' => row['trackTimeMillis'], 'content_rating' => row['trackExplicitness'],
        'release_date' => row['releaseDate'],
        'credits' => [ProviderEntityMetadata.credit({ 'name' => row['artistName'], 'id' => row['artistId'] },
                                                    'Track artist', 'iTunes', kind: 'artist')].compact }.compact
    end
  end

  def self.musicbrainz(data)
    Array(data['media']).flat_map do |disc|
      Array(disc['tracks']).filter_map do |row|
        recording = row['recording'] || {}
        next if row['id'].blank? || (row['title'] || recording['title']).blank?

        { 'provider_id' => "musicbrainz:#{row['id']}", 'title' => row['title'] || recording['title'],
          'disc_number' => disc['position'], 'track_number' => row['position'],
          'duration_ms' => row['length'] || recording['length'], 'isrc' => Array(recording['isrcs']).first,
          'credits' => (ProviderEntityMetadata.musicbrainz(row, 'Track artist') +
                        ProviderEntityMetadata.musicbrainz(recording, 'Track artist')).uniq }.compact
      end
    end
  end

  def self.reconcile(album, rows)
    rows.count do |row|
      track = album.album_tracks.find_or_initialize_by(provider_id: row.fetch('provider_id'))
      track.assign_attributes(row.slice('title', 'disc_number', 'track_number', 'duration_ms', 'isrc',
                                        'content_rating', 'release_date', 'credits'))
      changed = track.changed?
      track.save! if changed
      changed
    end
  end
end
