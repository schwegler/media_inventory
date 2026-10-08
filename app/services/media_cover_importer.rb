# frozen_string_literal: true

require 'tempfile'
require 'digest'

class MediaCoverImporter
  MAX_BYTES = 5.megabytes
  IMAGE_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  LOCKS = Array.new(32) { Mutex.new }.freeze
  DOWNLOAD_SLOTS = SizedQueue.new(2)
  2.times { DOWNLOAD_SLOTS << true }

  def self.call(item, source_url)
    LOCKS[Digest::SHA256.hexdigest(source_url).to_i(16) % LOCKS.length].synchronize do
      slot = DOWNLOAD_SLOTS.pop
      begin
        import(item, source_url)
      ensure
        DOWNLOAD_SLOTS << slot
      end
    end
  end

  def self.import(item, source_url)
    item.reload
    return unless current_selection?(item, source_url)
    if item.cover_image.attached? && item.cover_image.blob.metadata['remote_source'] == source_url &&
       stored_file?(item.cover_image.blob)
      return
    end

    source_key = "media-cover-source-#{Digest::SHA256.hexdigest(source_url)}"
    blob = local_blob(source_url) || cached_blob(source_key) || download_blob(source_url)
    MediaSources::Registry::CACHE.write(source_key, blob.id, expires_in: 7.days)
    item.with_lock { item.cover_image.attach(blob) if current_selection?(item, source_url) }
  rescue JSON::ParserError, MediaSources::Http::Error, Timeout::Error, SocketError,
         IOError, SystemCallError, OpenSSL::SSL::SSLError => e
    Rails.logger.warn "Cover import failed for #{item.class.name}##{item.id}: #{e.class}"
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

  def self.download_blob(source_url)
    Tempfile.create(['media-cover', '.image']) do |file|
      file.binmode
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
      image_url = resolve_legacy_steam_url(source_url, deadline: deadline)
      MediaSources::Http.get(image_url, max_bytes: MAX_BYTES,
                                        deadline: deadline) { |chunk, _type| file.write(chunk) }
      file.flush
      raise MediaSources::Http::Error, 'Empty image' if File.empty?(file.path)

      file.rewind
      content_type = Marcel::MimeType.for(file)
      raise MediaSources::Http::Error, 'Unsupported image' unless IMAGE_TYPES.include?(content_type)

      digest = Digest::SHA256.file(file.path).hexdigest
      file.rewind
      store_blob(file, digest, content_type, source_url)
    end
  end

  def self.store_blob(file, digest, content_type, source_url)
    key = "media-covers/#{digest}"
    blob = ActiveStorage::Blob.find_by(key: key)
    if blob
      blob.upload(file, identify: false) unless stored_file?(blob)
      return blob
    end

    ActiveStorage::Blob.create_and_upload!(
      io: file, key: key, filename: "#{digest}.#{content_type.split('/').last}",
      content_type: content_type, identify: false, metadata: { remote_source: source_url }
    )
  rescue ActiveRecord::RecordNotUnique
    ActiveStorage::Blob.find_by!(key: key)
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
    match = url.match(%r{\Ahttps://[^/]*steamstatic\.com/(?:store_item_assets/)?steam/apps/(\d+)/library_600x900\.jpg\z})
    return url unless match

    data = JSON.parse(MediaSources::Http.get("https://store.steampowered.com/api/appdetails?appids=#{match[1]}",
                                             deadline: deadline))
    details = data.dig(match[1], 'data') || {}
    details['header_image'].presence || details['capsule_image'].presence || url
  end
end
