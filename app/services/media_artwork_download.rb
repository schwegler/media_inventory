# frozen_string_literal: true

require 'tempfile'
require 'digest'

class MediaArtworkDownload
  def self.call(source_url, deadline: nil)
    source_hash = Digest::SHA256.hexdigest(source_url)
    existing = MediaArtworkSource.includes(:blob).find_by(source_hash: source_hash)
    return existing.blob if existing && MediaCoverImporter.stored_file?(existing.blob)

    deadline ||= Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
    Tempfile.create(['media-cover', '.image']) do |file|
      download(file, source_url, deadline)
      MediaArtworkDecoder.normalized(file.path) do |preview|
        blob = store_blob(preview, source_url)
        MediaArtworkSource.upsert({ source_hash: source_hash, source_url: source_url, blob_id: blob.id,
                                    retrieved_at: Time.current, created_at: Time.current, updated_at: Time.current },
                                  unique_by: :source_hash)
        blob
      end
    end
  end

  def self.download(file, source_url, deadline)
    file.binmode
    image_url = MediaCoverImporter.resolve_legacy_steam_url(source_url, deadline: deadline)
    MediaSources::Http.get(image_url, max_bytes: MediaCoverImporter::MAX_BYTES, deadline: deadline) do |chunk, type|
      if type.present? && !MediaCoverImporter::IMAGE_TYPES.include?(type.split(';').first)
        raise MediaSources::Http::Error, 'Unsupported response content type'
      end

      file.write(chunk)
    end
    file.flush
    raise MediaSources::Http::Error, 'Empty image' if File.empty?(file.path)

    file.rewind
    return if MediaCoverImporter::IMAGE_TYPES.include?(Marcel::MimeType.for(file))

    raise MediaSources::Http::Error, 'Unsupported image'
  end

  def self.store_blob(file, source_url)
    digest = Digest::SHA256.file(file.path).hexdigest
    key = "media-covers/#{digest}"
    blob = ActiveStorage::Blob.find_by(key: key)
    if blob
      blob.upload(file, identify: false) unless MediaCoverImporter.stored_file?(blob)
      return blob
    end

    quota = ENV.fetch('MEDIA_ARTWORK_QUOTA_MB', '512').to_i.clamp(1, 100_000).megabytes
    used = ActiveStorage::Blob.where("key LIKE 'media-covers/%'").sum(:byte_size)
    raise MediaSources::Http::Error, 'Artwork storage quota reached' if used + file.size > quota

    ActiveStorage::Blob.create_and_upload!(io: file, key: key, filename: "#{digest}.webp",
                                           content_type: 'image/webp', identify: false,
                                           metadata: { remote_source: source_url })
  rescue ActiveRecord::RecordNotUnique
    ActiveStorage::Blob.find_by!(key: key)
  end
end
