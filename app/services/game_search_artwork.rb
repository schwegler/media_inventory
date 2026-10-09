# frozen_string_literal: true

class GameSearchArtwork
  DOWNLOAD_ERRORS = [MediaSources::Http::Error, IOError, SystemCallError, Timeout::Error,
                     SocketError, OpenSSL::SSL::SSLError].freeze

  def self.call(results)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
    results.first(20).each_with_index.map do |result, index|
      next result if result[:thumbnail_url]&.start_with?('/')

      candidates = if index < 5
                     GameArtworkResolver.candidates(result, results: results, deadline: deadline)
                   elsif result[:source] != 'InternetArchive'
                     [{ url: result[:thumbnail_url], provider: result[:source], storage_eligible: true }]
                   else
                     []
                   end
      render_result(result, candidates, deadline, allow_download: index < 5)
    end
  end

  def self.render_result(result, candidates, deadline, allow_download: true)
    candidates.each do |candidate|
      next unless candidate[:storage_eligible] && candidate[:url].present?

      blob = acquire(candidate, deadline, allow_download: allow_download)
      next unless blob

      local = Rails.application.routes.url_helpers.rails_storage_proxy_path(blob, only_path: true)
      return result.merge(thumbnail_url: local, cover_source_url: local, artwork_source: candidate[:provider],
                          artwork_match: candidate[:matched_by], artwork_status: 'ready')
    end
    result.merge(thumbnail_url: nil, cover_source_url: result[:thumbnail_url], artwork_status: 'missing')
  end

  def self.acquire(candidate, deadline, allow_download: true)
    source_hash = Digest::SHA256.hexdigest(candidate[:url])
    key = "game-search-artwork-#{source_hash}"
    blob = MediaCoverImporter.cached_blob(key)
    unless blob
      mapping = MediaArtworkSource.includes(:blob).find_by(source_hash: source_hash)
      blob = mapping.blob if mapping && MediaCoverImporter.stored_file?(mapping.blob)
    end
    return blob if blob
    return unless allow_download
    return if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    return if MediaSources::Registry::CACHE.read([key, 'failed'])

    blob = MediaCoverImporter.with_download_slot { MediaCoverImporter.download_blob(candidate[:url], deadline: deadline) }
    MediaArtworkSource.find_by(source_hash: source_hash)&.update!(provenance: candidate.except(:url).stringify_keys)
    MediaSources::Registry::CACHE.write(key, blob.id, expires_in: 7.days)
    blob
  rescue *DOWNLOAD_ERRORS
    MediaSources::Registry::CACHE.write([key, 'failed'], true, expires_in: 5.minutes)
    nil
  end
end
