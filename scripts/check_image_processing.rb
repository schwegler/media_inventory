# frozen_string_literal: true

# Run with bundle exec ruby; never require config/environment or boot Rails here.
# All inputs are benign synthetic fixtures, and all output stays in a temp dir.
require 'tmpdir'
require 'active_support/core_ext/numeric/bytes'
require_relative '../app/services/media_sources/http'
require_relative '../app/services/media_artwork_decoder'

module ImageProcessingCheck
  # Exercise the inherited guard while proving unsupported bytes never reach its
  # subprocess boundary. Successful raster checks below use the real decoder.
  class PreDecodeCheck < MediaArtworkDecoder
    def self.execute(*)
      raise 'Unsupported bytes reached ImageMagick'
    end
  end

  module_function

  def assert(condition, message)
    raise message unless condition
  end

  def convert!(*)
    output, error, status = Open3.capture3(%w[convert convert], *MediaArtworkDecoder::COMMAND, *)
    assert(status.success?, "ImageMagick check failed: #{error.strip}")
    output.strip
  end

  def raster_fixtures(directory)
    paths = %w[png jpg webp gif].to_h { |format| [format, File.join(directory, "raster.#{format}")] }
    convert!('-size', '64x32', 'xc:none', '-fill', 'red', '-draw', 'rectangle 16,8 47,23', "PNG:#{paths['png']}")
    convert!(paths['png'], '-background', 'white', '-alpha', 'remove', '-alpha', 'off', "JPEG:#{paths['jpg']}")
    convert!(paths['png'], "WEBP:#{paths['webp']}")
    convert!('-delay', '10', '-size', '64x32', 'xc:red', 'xc:blue', '-loop', '0', "GIF:#{paths['gif']}")
    paths
  end

  def check_rasters(directory)
    paths = raster_fixtures(directory)
    paths.each do |format, path|
      assert(MediaArtworkDecoder.validate!(path) == [64, 32], "#{format}: incorrect source dimensions")
      MediaArtworkDecoder.normalized(path, dimensions: '16x16') do |preview|
        assert(MediaArtworkDecoder.validate!(preview.path) == [16, 8], "#{format}: incorrect resized dimensions")
        header = File.binread(preview.path, 12)
        assert(header.start_with?('RIFF') && header.end_with?('WEBP'), "#{format}: output is not WebP")
        assert(convert!(preview.path, '-format', '%n', 'info:') == '1', "#{format}: output has multiple frames")
      end
    end
    MediaArtworkDecoder.normalized(paths['png']) do |preview|
      assert(MediaArtworkDecoder.validate!(preview.path) == [64, 32], 'Small images must not be enlarged')
      assert(convert!(preview.path, '-format', '%[opaque]', 'info:').downcase == 'false', 'PNG alpha was lost')
    end
    MediaArtworkDecoder.normalized(paths['gif']) do |preview|
      red, blue = convert!(preview.path, '-format', '%[fx:r] %[fx:b]', 'info:').split.map(&:to_f)
      assert(red > 0.9 && blue < 0.1, 'GIF normalization did not preserve the first (red) frame')
    end
  end

  def blank_pdf
    objects = ['<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
               '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 72 72] /Resources << >> >>']
    data = +"%PDF-1.4\n"
    offsets = objects.each_with_index.map do |body, index|
      offset = data.bytesize
      data << "#{index + 1} 0 obj\n#{body}\nendobj\n"
      offset
    end
    xref = data.bytesize
    data << "xref\n0 4\n0000000000 65535 f \n"
    offsets.each { |offset| data << format("%010d 00000 n \n", offset) }
    data << "trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n"
  end

  def rejected_fixtures
    {
      'pdf' => blank_pdf,
      'ps' => "%!PS-Adobe-3.0\n%%BoundingBox: 0 0 10 10\nshowpage\n%%EOF\n",
      'eps' => "%!PS-Adobe-3.0 EPSF-3.0\n%%BoundingBox: 0 0 10 10\nshowpage\n%%EOF\n",
      'svg' => '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"/>',
      'txt' => 'This is not a raster image.'
    }
  end

  def assert_rejected(path, operation)
    PreDecodeCheck.public_send(operation, path) { raise 'Unsupported bytes were transformed' }
    raise "Unsupported input accepted by #{operation}: #{File.basename(path)}"
  rescue MediaSources::Http::Error => e
    assert(e.message == 'Unsupported image', "Unexpected rejection: #{e.message}")
  end

  def check_document_policy(input)
    _output, error, status = Open3.capture3(%w[convert convert], *MediaArtworkDecoder::COMMAND, input, 'null:')
    policy_error = error.match?(/security policy|not authorized/i)
    document_coder = error.match?(/[`'"](?:PDF|PS[23]?|EPS[23]?|EPI|EPT|XPS)[`'"]/i)
    # A missing gs binary, a malformed document, or another denied coder does
    # not satisfy this check: the document coder itself must be policy-denied.
    assert(!status.success? && policy_error && document_coder, "Document policy did not deny #{input}: #{error.strip}")
  end

  def check_delegate_policy
    last = convert!('-list', 'policy').split(/^\s*Policy:\s*/).grep(/\ADelegate\s*\n/).last
    denied = last&.match?(/^\s*rights:\s*None\s*$/) && last.match?(/^\s*pattern:\s*\*\s*$/)
    assert(denied, 'The last delegate policy must deny all external delegates')
  end

  def check_rejections(directory)
    rejected_fixtures.each do |format, bytes|
      ["document.#{format}", "spoofed-#{format}.jpg"].each do |name|
        path = File.join(directory, name)
        File.binwrite(path, bytes)
        %i[validate! normalized].each { |operation| assert_rejected(path, operation) }
        next unless %w[pdf ps eps].include?(format)

        check_document_policy("#{format.upcase}:#{path}[0]")
        check_document_policy("#{path}[0]")
      end
    end
  end

  def run
    check_delegate_policy
    Dir.mktmpdir('trove-image-check-') do |directory|
      check_rasters(directory)
      check_rejections(directory)
    end
    puts 'Image-processing checks passed: rasters, predecode guard, document policy, and delegate policy.'
  end
end

ImageProcessingCheck.run
