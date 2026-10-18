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
end
