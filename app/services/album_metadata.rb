# frozen_string_literal: true

class AlbumMetadata
  class EditionConflict < StandardError; end

  def self.itunes(rows)
    tracks = Array(rows).select do |row|
      row['wrapperType'] == 'track' && (row['kind'].blank? || %w[song music-video feature-movie].include?(row['kind']))
    end
    tracks.filter_map do |row|
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
    return 0 if rows.blank?

    album.with_lock do
      validate_edition!(album.album_tracks.to_a, rows)
      rows.count do |row|
        track = album.album_tracks.find_by(provider_id: row.fetch('provider_id'))
        track ||= album.album_tracks.build(provider_id: row.fetch('provider_id'))

        attributes = row.slice('title', 'disc_number', 'track_number', 'duration_ms', 'isrc',
                               'content_rating', 'release_date', 'credits')
        # No historical per-field provenance exists for tracks. Conservatively
        # fill blanks only, preserving user edits and existing correct ordering.
        attributes.select! { |field, _| track.new_record? || track.public_send(field).blank? }
        track.assign_attributes(attributes)
        track.provider_id = row.fetch('provider_id')
        changed = track.changed?
        track.save! if changed
        changed
      end
    end
  end

  def self.validate_edition!(existing, rows)
    # A position is not an identity: editions can reorder songs. Validate the
    # whole response before writing; matching IDs retain any user-edited order.
    ids = existing.map(&:provider_id)
    positions = existing.index_by { |track| [track.disc_number, track.track_number] }
    rows.each do |row|
      next if ids.include?(row['provider_id'])

      position = positions[[row['disc_number'], row['track_number']]]
      raise EditionConflict if position && position.provider_id != row['provider_id']
    end
  end
end
