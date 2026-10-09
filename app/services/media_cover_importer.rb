# frozen_string_literal: true

require 'digest'

class MediaCoverImporter
  MAX_BYTES = 5.megabytes
  IMAGE_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  LOCKS = Array.new(32) { Mutex.new }.freeze
  DOWNLOAD_SLOTS = SizedQueue.new(2)
  2.times { DOWNLOAD_SLOTS << true }

  def self.call(item, source_url)
    LOCKS[Digest::SHA256.hexdigest(source_url).to_i(16) % LOCKS.length].synchronize do
      with_download_slot { import(item, source_url) }
    end
  end

  def self.with_download_slot
    slot = DOWNLOAD_SLOTS.pop
    yield
  ensure
    DOWNLOAD_SLOTS << slot if slot
  end

  def self.import(item, source_url)
    item.reload
    return unless current_selection?(item, source_url)

    return if ready?(item, source_url)

    health = CoverImport.find_or_create_by!(item: item) { |entry| entry.source_url = source_url }
    health.update!(source_url: source_url, state: 'processing', attempted_at: Time.current,
                   attempts: health.attempts + 1, failure_reason: nil)
    source_key = "media-cover-source-#{Digest::SHA256.hexdigest(source_url)}"
    blob = resolve_blob(source_url, source_key)
    MediaSources::Registry::CACHE.write(source_key, blob.id, expires_in: 7.days)
    item.with_lock { item.cover_image.attach(blob) if current_selection?(item, source_url) }
    health.update!(state: 'ready', ready_at: Time.current)
  rescue JSON::ParserError, MediaSources::Http::Error, Timeout::Error, SocketError,
         IOError, SystemCallError, OpenSSL::SSL::SSLError => e
    health&.update!(state: 'failed', failure_reason: e.is_a?(MediaSources::Http::Error) ? e.message : e.class.name)
    Rails.logger.warn "Cover import failed for #{item.class.name}##{item.id}: #{e.class}"
  end

  def self.resolve_blob(source_url, source_key)
    local = local_blob(source_url)
    return local if local && stored_file?(local)

    remote = local&.metadata&.fetch('remote_source', nil)
    raise MediaSources::Http::Error, 'Missing local image' if local && remote.blank?

    cached_blob(source_key) || download_blob(remote || source_url)
  end

  def self.ready?(item, source_url)
    return false unless item.cover_image.attached?

    blob = item.cover_image.blob
    blob.service.delete(blob.key) if CoverImport.exists?(item: item, failure_reason: 'Corrupted stored image')
    blob.metadata['remote_source'] == source_url && stored_file?(blob)
  end

  def self.current_selection?(item, source_url)
    item.thumbnail_url == source_url &&
      (!item.cover_image.attached? || item.cover_image.blob.metadata['remote_source'].present?)
  end

  def self.cached_blob(key)
    id = MediaSources::Registry::CACHE.read(key)
    blob = ActiveStorage::Blob.find_by(id: id) if id
    blob if blob && stored_file?(blob)
  end

  def self.download_blob(source_url, deadline: nil)
    MediaArtworkDownload.call(source_url, deadline: deadline)
  end

  def self.validate_pixels!(path)
    MediaArtworkDecoder.validate!(path)
  end

  def self.local_blob(url)
    match = url.match(%r{\A/rails/active_storage/blobs/(?:redirect|proxy)/([^/]+)/[^?#]+\z})
    return ActiveStorage::Blob.find_signed(match[1]) if match

    match = url.match(%r{\A/media/covers/(movie|tv_show|album|video_game|comic|book|tv_episode|comic_issue)/(\d+)\z})
    return unless match

    item = match[1].camelize.constantize.find_by(id: match[2])
    item.cover_image.blob if item&.cover_image&.attached?
  end

  def self.stored_file?(blob)
    blob.service.exist?(blob.key)
  end

  def self.resolve_legacy_steam_url(url, deadline: nil)
    uri = URI.parse(url)
    if uri.instance_of?(URI::HTTP) && uri.port == 80
      uri.scheme = 'https'
      uri.port = 443
      url = uri.to_s
    end
    uri = MediaSources::Http.validated_uri(url)
    steam_host = uri.host.end_with?('.steamstatic.com') || uri.host == 'steamcdn-a.akamaihd.net'
    match = uri.path.match(%r{\A/(?:store_item_assets/)?steam/apps/(\d+)/library_600x900\.jpg\z})
    return url unless steam_host && match

    data = JSON.parse(MediaSources::Http.get("https://store.steampowered.com/api/appdetails?appids=#{match[1]}",
                                             deadline: deadline))
    details = data.dig(match[1], 'data') || {}
    details['header_image'].presence || details['capsule_image'].presence || url
  end
end
