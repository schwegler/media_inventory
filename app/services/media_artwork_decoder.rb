# frozen_string_literal: true

require 'open3'
require 'timeout'
require 'tempfile'

class MediaArtworkDecoder
  COMMAND = ['-limit', 'memory', '64MiB', '-limit', 'map', '64MiB',
             '-limit', 'disk', '0', '-limit', 'time', '5'].freeze

  def self.validate!(path)
    output, _error, status = execute("#{path}[0]", '-format', '%w %h', 'info:')
    width, height = output.split.map(&:to_i)
    valid = status.success? && width&.positive? && height&.positive? && width * height <= 20_000_000
    raise MediaSources::Http::Error, 'Invalid image pixels or dimensions' unless valid

    [width, height]
  end

  def self.normalized(path, dimensions: '600x900')
    validate!(path)
    Tempfile.create(['media-cover-preview', '.webp']) do |preview|
      _output, _error, status = execute("#{path}[0]", '-auto-orient', '-resize', "#{dimensions}>",
                                        '-strip', '-quality', '82', "webp:#{preview.path}")
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
end
