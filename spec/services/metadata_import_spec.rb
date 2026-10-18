# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MetadataImport do
  it 'maps OpenLibrary comic authors to writers and imports edition cover and publication year' do
    stub_request(:get, 'https://openlibrary.org/works/OL42W.json').to_return(body: {
      authors: [{ author: { key: '/authors/OL1A' } }], subjects: ['Comics']
    }.to_json)
    stub_request(:get, 'https://openlibrary.org/authors/OL1A.json').to_return(body: { name: 'Comic writer' }.to_json)
    stub_request(:get, 'https://openlibrary.org/works/OL42W/editions.json?limit=1').to_return(body: {
      entries: [{ publish_date: 'January 1, 1899', covers: [-1, 45], publishers: ['Press'], 'isbn_13' => ['123'] }]
    }.to_json)
    result = described_class.preview({ title: 'Comic', api_id: 'openlibrary_/works/OL42W' }.with_indifferent_access,
                                     'comic')
    expect(result).to include('writer' => 'Comic writer', 'publisher' => 'Press', 'thumbnail_url' => 'https://covers.openlibrary.org/b/id/45-L.jpg')
    expect(result[:metadata_credits_data].map { |row| row['name'] }).to include('Comic writer', 'Press')
    expect(result[:metadata_details]['isbn_13']).to eq(['123'])
    expect(result).not_to have_key(:author)
    book = described_class.preview({ title: 'Book', api_id: 'openlibrary_/works/OL42W' }.with_indifferent_access, 'book')
    expect(book).to include('release_year' => 1899, 'author' => 'Comic writer')
    work = described_class.preview({ title: 'Book', api_id: 'openlibrary_/works/OL42W', release_year: 1900 }
                                    .with_indifferent_access, 'book')
    expect(work[:release_year]).to eq(1900)
    expect(work[:metadata_details]['edition_note']).to include('one available edition')
  end

  it 'retains the actual cover source rather than storing a rendered derivative' do
    adapter = instance_double(MetadataProvider, call: [{ thumbnail_url: 'https://example.com/new.jpg' }, []],
                                                partial: false, provider: 'TMDB')
    allow(MetadataProvider).to receive(:new).and_return(adapter)
    data = { title: 'Movie', api_id: '42', thumbnail_url: '/rendered-cover',
             cover_source_url: 'https://example.com/original.jpg' }.with_indifferent_access
    expect(described_class.preview(data,
                                   'movie')).to include('cover_source_url' => 'https://example.com/original.jpg',
                                                        'thumbnail_url' => '/rendered-cover')
  end

  it 'maps iTunes video descriptions, runtime and advisory ratings to displayed metadata' do
    stub_request(:get, 'https://itunes.apple.com/lookup?id=42').to_return(body: {
      results: [{ artistName: 'Director', longDescription: '<p>A film</p>', trackTimeMillis: 7_200_000,
                  contentAdvisoryRating: 'PG', releaseDate: '1899-01-01' }]
    }.to_json)
    result = described_class.preview({ title: 'Film', api_id: 'itunes_42' }.with_indifferent_access, 'movie')
    expect(result[:metadata_details]).to include('description' => 'A film', 'Runtime' => 120,
                                                 'collectionExplicitness' => 'PG')
    expect(result[:release_year]).to eq(1899)
  end

  it 'retains ComicVine series description and issue count without downloading issues in the preview' do
    ApiConfiguration.create!(source_name: 'ComicVine', is_active: true, access_token: 'test')
    stub_request(:get, 'https://comicvine.gamespot.com/api/volume/4050-42/?api_key=test&format=json').to_return(body: {
      status_code: 1, results: { description: '<p>A series</p>', start_year: '2001', count_of_issues: 24 }
    }.to_json)
    result = described_class.preview({ title: 'Series', api_id: '42' }.with_indifferent_access, 'comic')
    expect(result[:metadata_details]).to include('description' => 'A series', 'start_year' => '2001',
                                                 'count_of_issues' => 24)
    expect(WebMock).not_to have_requested(:get, %r{comicvine.gamespot.com/api/issues/})
  end
end
