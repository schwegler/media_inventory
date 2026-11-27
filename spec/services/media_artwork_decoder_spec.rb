# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaArtworkDecoder do
  {
    'PDF' => "%PDF-1.4\n%%EOF\n",
    'PostScript' => "%!PS-Adobe-3.0\nshowpage\n",
    'EPS' => "%!PS-Adobe-3.0 EPSF-3.0\n%%BoundingBox: 0 0 10 10\nshowpage\n",
    'SVG' => '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"></svg>',
    'unknown data' => 'This is not an image.',
    'empty data' => ''
  }.each do |format, bytes|
    it "rejects #{format} disguised as PNG before starting ImageMagick" do
      Tempfile.create(['unsupported-original', '.png']) do |original|
        original.binmode
        original.write(bytes)
        original.flush
        expect(Open3).not_to receive(:capture3)

        expect { described_class.validate!(original.path) }
          .to raise_error(MediaSources::Http::Error, 'Unsupported image')
        expect { described_class.normalized(original.path) { raise 'Should not transform' } }
          .to raise_error(MediaSources::Http::Error, 'Unsupported image')
      end
    end
  end

  %w[JPEG PNG GIF WEBP].each do |format|
    it "normalizes real #{format} bytes with an unrelated filename using the matching raster decoder" do
      Tempfile.create(['raster-original', '.image']) do |original|
        _output, error, status = Open3.capture3(%w[convert convert], '-size', '80x60',
                                                'xc:navy', "#{format}:#{original.path}")
        expect(status.success?).to be(true), error
        allow(Open3).to receive(:capture3).and_call_original

        described_class.normalized(original.path) do |preview|
          expect(described_class.validate!(preview.path)).to eq([80, 60])
          expect(Marcel::MimeType.for(preview)).to eq('image/webp')
        end
        expect(Open3).to have_received(:capture3).with(
          %w[convert convert], *described_class::COMMAND, '-ping', "#{format}:#{original.path}[0]",
          '-format', '%w %h', 'info:'
        )
      end
    end
  end

  it 'rejects malformed raster bytes after identifying their PNG signature' do
    Tempfile.create(['truncated-original', '.png']) do |original|
      original.binmode
      original.write(File.binread(Rails.root.join('spec/fixtures/files/valid-cover.png'), 24))
      original.flush
      expect(Marcel::MimeType.for(Pathname.new(original.path))).to eq('image/png')

      expect { described_class.normalized(original.path) { raise 'Should not transform' } }
        .to raise_error(MediaSources::Http::Error, 'Invalid image pixels or dimensions')
    end
  end

  %w[jpg png].each do |format|
    it "normalizes a large provider #{format.upcase} within the artwork resource limits" do
      Tempfile.create(['provider-original', ".#{format}"]) do |original|
        # This poster needs more pixel-cache memory than the old 64 MiB budget
        # on HDRI builds, despite having a small compressed download size.
        _output, error, status = Open3.capture3(%w[convert convert], '-size', '2160x2880',
                                                'gradient:navy-orange', original.path)
        expect(status.success?).to be(true), error
        expect(described_class.validate!(original.path)).to eq([2160, 2880])

        described_class.normalized(original.path) do |preview|
          expect(described_class.validate!(preview.path)).to eq([600, 800])
          expect(Marcel::MimeType.for(preview)).to eq('image/webp')
        end
      end
    end
  end

  it 'rejects originals above the pixel limit before transforming them' do
    Tempfile.create(['oversized-original', '.png']) do |original|
      _output, error, status = Open3.capture3(%w[convert convert], '-size', '4500x4500',
                                              'xc:navy', original.path)
      expect(status.success?).to be(true), error
      expect { described_class.normalized(original.path) { raise 'Should not transform' } }
        .to raise_error(MediaSources::Http::Error, 'Invalid image pixels or dimensions')
    end
  end
end
