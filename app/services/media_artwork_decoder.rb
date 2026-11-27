# frozen_string_literal: true

require 'open3'
require 'timeout'
require 'tempfile'
require 'marcel'

class MediaArtworkDecoder
  INPUT_FORMATS = {
    'image/jpeg' => 'JPEG',
    'image/png' => 'PNG',
    'image/webp' => 'WEBP',
    'image/gif' => 'GIF'
  }.freeze

  # Provider originals can need far more pixel-cache space than their compressed
  # download size. Spill to bounded temporary storage instead of rejecting them.
  COMMAND = ['-limit', 'memory', '32MiB', '-limit', 'map', '0',
             '-limit', 'disk', '256MiB', '-limit', 'thread', '1', '-limit', 'time', '5'].freeze

  def self.validate!(path)
    output, _error, status = execute('-ping', raster_input(path), '-format', '%w %h', 'info:')
    width, height = output.split.map(&:to_i)
    valid = status.success? && width&.positive? && height&.positive? && width * height <= 20_000_000
    raise MediaSources::Http::Error, 'Invalid image pixels or dimensions' unless valid

    [width, height]
  end

  def self.normalized(path, dimensions: '600x900')
    validate!(path)
    Tempfile.create(['media-cover-preview', '.webp']) do |preview|
      _output, _error, status = execute('-define', "jpeg:size=#{dimensions}", raster_input(path), '-auto-orient',
                                        '-resize', "#{dimensions}>", '-strip', '-quality', '82', "webp:#{preview.path}")
      raise MediaSources::Http::Error, 'Image transformation failed' unless status.success? && !File.empty?(preview.path)

      preview.binmode
      preview.rewind
      yield preview
    end
  end

  def self.execute(*arguments)
    Timeout.timeout(5) { Open3.capture3(%w[convert convert], *COMMAND, *arguments) }
  rescue Errno::ENOENT, Timeout::Error
    raise MediaSources::Http::Error, 'Image decoder unavailable or timed out'
  end

  def self.raster_input(path)
    # Ignore filenames and declared MIME types, including those on stored blobs.
    # Choose the raster decoder before ImageMagick can auto-detect a document.
    mime = File.open(path, 'rb') { |io| Marcel::MimeType.for(io) }
    format = INPUT_FORMATS[mime]
    raise MediaSources::Http::Error, 'Unsupported image' unless format

    "#{format}:#{path}[0]"
  end
  private_class_method :raster_input
end
