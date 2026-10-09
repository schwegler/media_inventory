# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateMediaArtworkRenditionJob do
  include ActiveJob::TestHelper

  def source_blob
    io = StringIO.new(File.binread(Rails.root.join('spec/fixtures/files/landscape-cover.png')))
    ActiveStorage::Blob.create_and_upload!(io: io,
                                           filename: 'landscape.png', content_type: 'image/png')
  end

  it 'creates genuine bounded WebP derivatives from stored pixels without redownloading or stretching' do
    source = source_blob
    MediaArtworkRendition.request(source)
    perform_enqueued_jobs(only: described_class)
    rows = source.artwork_renditions.order(:requested_width)
    expect(rows.pluck(:state)).to eq(%w[ready ready])
    expect(rows.pluck(:width)).to eq([180, 360])
    rows.each do |row|
      expect(row.width.to_f / row.height).to be_within(0.02).of(800.0 / 450)
      expect(row.blob.content_type).to eq('image/webp')
      row.blob.open { |file| expect(MediaArtworkDecoder.validate!(file.path)).to eq([row.width, row.height]) }
    end
    expect(WebMock).not_to have_requested(:get, /.*/)
  end

  it 'deduplicates identical derivatives across distinct originals and requests only one job per size' do
    left = source_blob
    right = source_blob
    2.times { MediaArtworkRendition.request(left) }
    MediaArtworkRendition.request(right)
    expect(enqueued_jobs.count { |job| job[:job] == described_class }).to eq(4)
    perform_enqueued_jobs(only: described_class)
    MediaArtworkRendition.all.group_by(&:requested_width).each_value do |rows|
      expect(rows.map(&:blob_id).uniq.length).to eq(1)
    end
  end
  it 'retries a failed rendition once when explicitly requested again' do
    source = source_blob
    MediaArtworkRendition.request(source)
    clear_enqueued_jobs
    source.artwork_renditions.first.update!(state: 'failed', failure_reason: 'MissingFile')
    2.times { MediaArtworkRendition.request(source) }
    expect(enqueued_jobs.count { |job| job[:job] == described_class }).to eq(1)
    expect(source.artwork_renditions.where(state: 'failed')).to be_empty
  end
end
