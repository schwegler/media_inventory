# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PublicHomeCovers do
  include PublicHomeFixture

  it 'uses existing attached artwork, prioritizes real public picks and never calls external search' do
    records = build_public_home_fixture
    expect(MediaSearchService).not_to receive(:call)
    expect(MediaSearchService).not_to receive(:request)
    before = [Album.count, Book.count, Movie.count, VideoGame.count, LibraryItem.count]
    result = described_class.call([records.last])
    expect(result.first).to eq(records.last)
    expect(result.length).to eq(6)
    expect(result.map { |item| [item.class.name, item.id] }.uniq.length).to eq(6)
    expect([Album.count, Book.count, Movie.count, VideoGame.count, LibraryItem.count]).to eq(before)
  end

  it 'does not invent artwork or import remote thumbnails for an empty catalog' do
    Album.create!(title: 'Unstored album cover', importing_metadata: true, thumbnail_url: 'https://example.test/remote.jpg')
    expect(described_class.call([])).to eq([])
    expect(WebMock).not_to have_requested(:get, /example.test/)
  end
end
