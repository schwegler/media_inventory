# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaCoverImporter do
  let(:url) { 'https://covers.openlibrary.org/b/id/123-M.jpg' }
  let(:png) do
    File.binread(Rails.root.join('spec/fixtures/files/valid-cover.png'))
  end
  let(:item) { Book.create!(title: 'Cover test', thumbnail_url: url) }

  before do
    MediaSources::Registry::CACHE.clear
    stub_request(:get, url).to_return(body: png, headers: { 'Content-Type' => 'image/png' })
  end

  it 'stores selected images locally and reuses downloads for repeated imports' do
    described_class.call(item, url)
    expect(item.reload.cover_image).to be_attached
    expect(item.stored_cover_url).to start_with('/media/covers/')
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

  it 'attaches and reuses artwork when the filesystem cache is not writable' do
    allow(MediaSources::Registry::CACHE).to receive(:write).and_raise(Errno::EACCES)
    described_class.call(item, url)
    expect(item.reload.cover_image).to be_attached
    expect(CoverImport.find_by(item: item)).to have_attributes(state: 'ready', failure_reason: nil)

    another = Book.create!(title: 'Same artwork', thumbnail_url: url)
    described_class.call(another, url)
    expect(another.reload.cover_image.blob_id).to eq(item.cover_image.blob_id)
    expect(WebMock).to have_requested(:get, url).once
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

  it 'reuses absolute same-site proxy and redirect selections without HTTP or duplicate blobs' do
    original = Book.create!(title: 'Existing cover')
    original.cover_image.attach(io: StringIO.new(png), filename: 'cover.png', content_type: 'image/png')
    blob = original.cover_image.blob
    %w[proxy redirect].each do |action|
      local_url = "https://trove.schweg.xyz/rails/active_storage/blobs/#{action}/#{blob.signed_id}/cover.png?download=1"
      copy = Book.create!(title: 'Selected cover', thumbnail_url: local_url)
      expect { 2.times { described_class.call(copy, local_url) } }.not_to change(ActiveStorage::Blob, :count)
      expect(copy.reload.cover_image.blob_id).to eq(blob.id)
      expect(described_class.ready?(copy, local_url)).to be(true)
    end
    expect(WebMock).not_to have_requested(:get, /trove\.schweg\.xyz/)
  end

  it 'resolves local covers only against the configured origin' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('HOST', anything).and_return('catalog.example:8443')
    original = Book.create!(title: 'Existing cover')
    original.cover_image.attach(io: StringIO.new(png), filename: 'cover.png', content_type: 'image/png')
    path = original.stored_cover_url
    expect(described_class.local_blob("https://catalog.example:8443#{path}")).to eq(original.cover_image.blob)
    expect(described_class.local_blob("https://trove.schweg.xyz#{path}")).to be_nil
  end

  it 'does not treat lookalike hosts, credentials, ports or protocol-relative links as local' do
    original = Book.create!(title: 'Existing cover')
    original.cover_image.attach(io: StringIO.new(png), filename: 'cover.png', content_type: 'image/png')
    path = Rails.application.routes.url_helpers.rails_storage_proxy_path(original.cover_image.blob, only_path: true)
    ['https://evil.example', 'https://trove.schweg.xyz.evil.example', 'https://user@trove.schweg.xyz',
     'https://trove.schweg.xyz:444', 'http://trove.schweg.xyz', '//trove.schweg.xyz'].each do |origin|
      expect(described_class.local_blob("#{origin}#{path}")).to be_nil
    end
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

  it 'repairs legacy Steam CDN covers with query strings' do
    legacy = 'https://steamcdn-a.akamaihd.net/steam/apps/620/library_600x900.jpg?t=123'
    header = 'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/620/header.jpg'
    item.update!(thumbnail_url: legacy)
    stub_request(:get, /appdetails/).to_return(body: { '620' => { data: { header_image: header } } }.to_json)
    stub_request(:get, header).to_return(body: png)
    described_class.call(item, legacy)
    expect(item.reload.cover_image).to be_attached
    expect(WebMock).not_to have_requested(:get, legacy)
  end

  it 'imports RAWG artwork from its separate image host' do
    source = 'https://media.rawg.io/media/games/cover.jpg'
    item.update!(thumbnail_url: source)
    stub_request(:get, source).to_return(body: png)
    described_class.call(item, source)
    expect(item.reload.cover_image).to be_attached
    expect(WebMock).to have_requested(:get, source).once
  end

  it 'rejects oversized responses before storing a blob' do
    stub_request(:get, url).to_return(body: png, headers: { 'Content-Length' => (described_class::MAX_BYTES + 1).to_s })
    described_class.call(item, url)
    expect(item.reload.cover_image).not_to be_attached
    expect(item.stored_cover_url).to start_with('/media/covers/')
  end

  it 'rejects HTML masquerading as an image' do
    stub_request(:get, url).to_return(body: '<html>Error</html>', headers: { 'Content-Type' => 'image/jpeg' })
    described_class.call(item, url)
    expect(item.reload.cover_image).not_to be_attached
  end

  it 'reuses durable source mappings after the process cache is cleared' do
    described_class.call(item, url)
    MediaSources::Registry::CACHE.clear
    another = Book.create!(title: 'After restart', thumbnail_url: url)
    described_class.call(another, url)
    expect(another.reload.cover_image.blob_id).to eq(item.reload.cover_image.blob_id)
    expect(WebMock).to have_requested(:get, url).once
  end

  it 'repairs a missing locally selected search cover through its original source' do
    described_class.call(item, url)
    blob = item.reload.cover_image.blob
    path = Rails.application.routes.url_helpers.rails_storage_proxy_path(blob, only_path: true)
    local_url = "https://trove.schweg.xyz#{path}"
    item.update!(thumbnail_url: local_url)
    blob.service.delete(blob.key)
    MediaSources::Registry::CACHE.clear
    described_class.call(item, local_url)
    expect(item.reload.cover_image.blob_id).to eq(blob.id)
    expect(blob.service.exist?(blob.key)).to be(true)
    expect(WebMock).to have_requested(:get, url).twice
  end

  it 'rejects a truncated payload even with a valid PNG magic signature' do
    stub_request(:get, url).to_return(body: png.first(24), headers: { 'Content-Type' => 'image/png' })
    described_class.call(item, url)
    expect(item.reload.cover_image).not_to be_attached
    expect(CoverImport.find_by(item: item)).to have_attributes(state: 'failed',
                                                               failure_reason: 'Invalid image pixels or dimensions')
  end

  it 'rejects a valid image delivered with an HTML response type' do
    stub_request(:get, url).to_return(body: png, headers: { 'Content-Type' => 'text/html' })
    described_class.call(item, url)
    expect(item.reload.cover_image).not_to be_attached
  end

  it 'normalizes remote images into bounded WebP covers' do
    described_class.call(item, url)
    expect(item.reload.cover_image.blob.content_type).to eq('image/webp')
    expect(CoverImport.find_by(item: item).state).to eq('ready')
  end

  it 'limits background and HTTP recovery imports to two concurrent operations' do
    active = 0
    peak = 0
    mutex = Mutex.new
    entered = Queue.new
    release = Queue.new
    allow(described_class).to receive(:import) do
      mutex.synchronize do
        active += 1
        peak = [peak, active].max
      end
      entered << true
      release.pop
      mutex.synchronize { active -= 1 }
    end
    threads = 6.times.map { |i| Thread.new { described_class.call(nil, "https://covers.openlibrary.org/#{i}") } }
    2.times { entered.pop }
    expect(entered.empty?).to be(true)
    6.times { release << true }
    threads.each(&:join)
    expect(peak).to eq(2)
  end
end
