# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaArtworkDecoder do
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
