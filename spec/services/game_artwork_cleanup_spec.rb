# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'Artwork reference cleanup' do
  include ActiveJob::TestHelper

  it 'retains unattached derivatives used by an attached source while removing genuinely orphaned assets' do
    io = StringIO.new(File.binread(Rails.root.join('spec/fixtures/files/landscape-cover.png')))
    source = ActiveStorage::Blob.create_and_upload!(io: io,
                                                    filename: 'original.png', content_type: 'image/png')
    game = VideoGame.create!(title: 'Keep my derivatives')
    game.cover_image.attach(source)
    MediaArtworkRendition.request(source)
    perform_enqueued_jobs(only: GenerateMediaArtworkRenditionJob)
    derivatives = source.artwork_renditions.map(&:blob)
    derivatives.each { |blob| blob.update!(created_at: 8.days.ago) }
    png = File.binread(Rails.root.join('spec/fixtures/files/valid-cover.png'))
    key = "media-covers/orphan-#{SecureRandom.hex(8)}"
    orphan = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), key: key,
                                                    filename: 'orphan.png', content_type: 'image/png')
    orphan.update!(created_at: 8.days.ago)
    Rails.application.load_tasks unless Rake::Task.task_defined?('games:clean_artwork')
    task = Rake::Task['games:clean_artwork']
    previous = ENV.fetch('APPLY', nil)
    ENV['APPLY'] = '1'
    task.reenable
    expect { task.invoke }.to output(/Unreferenced cover blob/).to_stdout
    expect(ActiveStorage::Blob.exists?(orphan.id)).to be false
    derivatives.each { |blob| expect(ActiveStorage::Blob.exists?(blob.id)).to be true }
  ensure
    ENV['APPLY'] = previous
  end

  it 'preserves transparent logo pixels through normalization' do
    path = Rails.root.join('spec/fixtures/files/transparent-logo.png').to_s
    MediaArtworkDecoder.normalized(path) do |preview|
      channels, _error, status = MediaArtworkDecoder.execute(preview.path, '-format', '%[channels]', 'info:')
      expect(status).to be_success
      expect(channels).to include('a')
    end
  end
end
