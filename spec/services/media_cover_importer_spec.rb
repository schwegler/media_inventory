# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaCoverImporter do
  let(:url) { 'https://covers.openlibrary.org/b/id/123-M.jpg' }
  let(:png) do
    Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aO1sAAAAASUVORK5CYII=')
  end
  let(:item) { Book.create!(title: 'Cover test', thumbnail_url: url) }

  before do
    MediaSources::Registry::CACHE.clear
    stub_request(:get, url).to_return(body: png, headers: { 'Content-Type' => 'image/png' })
  end

  it 'stores selected images locally and reuses downloads for repeated imports' do
    described_class.call(item, url)
    expect(item.reload.cover_image).to be_attached
    expect(item.stored_cover_url).to start_with('/rails/active_storage/')
    another = Book.create!(title: 'Another', thumbnail_url: url)
    described_class.call(another, url)
    expect(another.cover_image.blob_id).to eq(item.cover_image.blob_id)
    expect(WebMock).to have_requested(:get, url).once
  end

  it 'does not fetch a stale selection or replace a manual upload' do
    item.update!(thumbnail_url: 'https://covers.openlibrary.org/b/id/456-M.jpg')
    described_class.call(item, url)
    item.cover_image.attach(io: StringIO.new(png), filename: 'manual.png', content_type: 'image/png')
    described_class.call(item, item.thumbnail_url)
    expect(item.cover_image.filename.to_s).to eq('manual.png')
    expect(WebMock).not_to have_requested(:get, url)
  end

  it 'reuses a signed local search result without downloading from the app' do
    original = Book.create!(title: 'Local cover')
    original.cover_image.attach(io: StringIO.new(png), filename: 'cover.png', content_type: 'image/png')
    local_url = original.stored_cover_url
    copy = Book.create!(title: 'Copy', thumbnail_url: local_url)
    described_class.call(copy, local_url)
    expect(copy.reload.cover_image.blob_id).to eq(original.cover_image.blob_id)
    expect(WebMock).not_to have_requested(:get, url)
  end

  it 'repairs guessed legacy Steam covers using the returned header image' do
    legacy = 'https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/620/library_600x900.jpg'
    header = 'https://shared.fastly.steamstatic.com/actual-cover.jpg'
    item.update!(thumbnail_url: legacy)
    stub_request(:get, /appdetails/).to_return(body: { '620' => { data: { header_image: header } } }.to_json)
    stub_request(:get, header).to_return(body: png)
    described_class.call(item, legacy)
    expect(item.reload.cover_image).to be_attached
    expect(WebMock).not_to have_requested(:get, legacy)
  end

  it 'rejects oversized responses before storing a blob' do
    stub_request(:get, url).to_return(body: png, headers: { 'Content-Length' => (described_class::MAX_BYTES + 1).to_s })
    described_class.call(item, url)
    expect(item.reload.cover_image).not_to be_attached
    expect(item.stored_cover_url).to be_nil
  end

  it 'rejects HTML masquerading as an image' do
    stub_request(:get, url).to_return(body: '<html>Error</html>', headers: { 'Content-Type' => 'image/jpeg' })
    described_class.call(item, url)
    expect(item.reload.cover_image).not_to be_attached
  end
end
