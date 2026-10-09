# frozen_string_literal: true

require 'rails_helper'
RSpec.describe GameSearchArtwork do
  let(:url) { 'https://shared.akamai.steamstatic.com/actual-header.jpg' }
  let(:png) { File.binread(Rails.root.join('spec/fixtures/files/valid-cover.png')) }
  before { MediaSources::Registry::CACHE.clear }
  it 'downloads and decodes an actual file, returns only a locally served preview and reuses it' do
    stub_request(:get, url).to_return(body: png, headers: { 'Content-Type' => 'image/png' })
    result = described_class.call([{ title: 'Game', thumbnail_url: url }]).first
    expect(result[:artwork_status]).to eq('ready')
    expect(result[:thumbnail_url]).to start_with('/rails/active_storage/blobs/proxy/')
    described_class.call([{ title: 'Game', thumbnail_url: url }])
    expect(WebMock).to have_requested(:get, url).once
    expect(ActiveStorage::Blob.last.service.exist?(ActiveStorage::Blob.last.key)).to be(true)
  end
  it 'retains games with failed images and negatively caches download failures' do
    stub_request(:get, url).to_return(status: 404)
    2.times do
      expect(described_class.call([{ title: 'Game',
                                     thumbnail_url: url }]).first).to include(title: 'Game', thumbnail_url: nil,
                                                                              artwork_status: 'missing')
    end
    expect(WebMock).to have_requested(:get, url).once
  end
end
