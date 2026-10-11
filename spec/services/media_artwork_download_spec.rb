# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaArtworkDownload do
  it 'imports a bounded ComicVine rendition when the original exceeds the download limit' do
    original = 'https://comicvine.gamespot.com/a/uploads/original/6/67663/5444890-01.jpg'
    rendition = original.sub('/original/', '/scale_large/')
    png = File.binread(Rails.root.join('spec/fixtures/files/valid-cover.png'))
    stub_request(:get, original).to_return(headers: { 'Content-Length' => '6000000' })
    stub_request(:get, rendition).to_return(body: png, headers: { 'Content-Type' => 'application/octet-stream' })

    blob = described_class.call(original)

    expect(blob.content_type).to eq('image/webp')
    expect(blob.metadata['remote_source']).to eq(original)
    expect(MediaCoverImporter.stored_file?(blob)).to be(true)
    expect(WebMock).to have_requested(:get, rendition).once
    expect(WebMock).not_to have_requested(:get, original)
  end

  it 'rejects a non-image ComicVine binary response' do
    url = 'https://comicvine.gamespot.com/a/uploads/scale_large/6/67663/broken.jpg'
    stub_request(:get, url).to_return(body: '<html>Unavailable</html>',
                                      headers: { 'Content-Type' => 'application/octet-stream' })

    expect { described_class.call(url) }.to raise_error(MediaSources::Http::Error, 'Unsupported image')
  end
end
