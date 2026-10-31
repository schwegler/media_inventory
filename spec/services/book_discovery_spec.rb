# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Book discovery editions' do
  before { MediaSources::Registry::CACHE.clear }

  def audio
    { 'wrapperType' => 'audiobook', 'collectionId' => 6_786_439_611, 'collectionName' => 'Witchwolf',
      'artistName' => 'Sam Burns & W.M. Fawkes', 'releaseDate' => '2025-10-28T07:00:00Z',
      'collectionViewUrl' => 'https://books.apple.com/us/audiobook/witchwolf/id6786439611',
      'artworkUrl100' => 'https://is1-ssl.mzstatic.com/cover/100x100bb.jpg' }
  end

  it 'finds Witchwolf as audio without calling it an ebook or confusing similarly named titles' do
    ebook = { kind: 'ebook', trackId: 10, trackName: 'Witch Wolf',
              artistName: 'Winter Pennington', releaseDate: '2010-01-01' }
    stub_request(:get, %r{itunes.apple.com/search})
      .with(query: hash_including('media' => 'ebook', 'country' => 'US'))
      .to_return(body: { results: [ebook] }.to_json)
    stub_request(:get, %r{itunes.apple.com/search})
      .with(query: hash_including('media' => 'audiobook', 'country' => 'US'))
      .to_return(body: { results: [audio] }.to_json)
    service = MediaSearchService.new('Witchwolf', 'book')
    results = service.send(:rank_results, service.send(:fetch_itunes_books, 'Witchwolf'))
    expect(results.first).to include(title: 'Witchwolf', api_id: 'itunes_6786439611', book_format: 'audiobook')
    expect(results.first[:book_edition_data]).to include(published_on: '2025-10-28', structure_kind: 'audio_segments')
    expect(results.last).to include(title: 'Witch Wolf', book_format: 'ebook')
  end

  it 'preserves distinct provider edition identities with identical title, author and year' do
    service = MediaSearchService.new('Witchwolf', 'book')
    first = BookProviderMetadata.apple(audio)
    second = BookProviderMetadata.apple(audio.merge('collectionId' => 2))
    expect(service.send(:rank_results, [first, second]).size).to eq(2)
  end

  it 'keeps audiobook candidates visible when there are many same-title ebook editions' do
    ebooks = 25.times.map do |index|
      BookProviderMetadata.apple({ 'kind' => 'ebook', 'trackId' => index + 1, 'trackName' => 'Frankenstein',
                                   'artistName' => 'Mary Shelley' })
    end
    audiobook = BookProviderMetadata.apple(audio.merge('collectionName' => 'Frankenstein',
                                                       'artistName' => 'Mary Shelley'))
    results = MediaSearchService.new('Frankenstein', 'book').send(:rank_results, ebooks + [audiobook])
    expect(results.size).to eq(20)
    expect(results).to include(audiobook)
  end

  it 'retains the working format after a provider failure and caches the successful request' do
    stub_request(:get, %r{itunes.apple.com/search}).with(query: hash_including('media' => 'ebook')).to_return(status: 503)
    stub_request(:get,
                 %r{itunes.apple.com/search}).with(query: hash_including('media' => 'audiobook'))
      .to_return(body: { results: [audio] }.to_json)
    service = MediaSearchService.new('Witchwolf', 'book')
    2.times { expect(service.send(:fetch_itunes_books, 'Witchwolf').sole[:book_format]).to eq('audiobook') }
    expect(WebMock).to have_requested(:get,
                                      %r{itunes.apple.com/search}).with(query: hash_including('media' => 'audiobook')).once
  end

  it 'reuses the manually added work, attaches audio once, and preserves publication date and reviews' do
    book = Book.create!(title: 'Witchwolf', author: 'Sam Burns & W.M. Fawkes', release_year: 2024)
    user = User.create!(name: 'Reader', email: 'book-identity@example.com', password: 'password123')
    entry = LibraryItem.create!(user: user, item: book, review: 'Original work review', rating: '4')
    data = BookProviderMetadata.apple(audio).with_indifferent_access
    2.times { expect(ShelfCatalogImport.call(Book, data)).to eq(book) }
    expect(Book.count).to eq(1)
    expect(book.book_editions.count).to eq(1)
    expect(book.book_editions.sole).to have_attributes(format: 'audiobook', published_on: Date.new(2025, 10, 28))
    expect(book.reload).to have_attributes(release_year: 2024, api_id: nil)
    expect(entry.reload).to have_attributes(review: 'Original work review', rating: '4')
    expect(DiscoveryResults.call([data], 'book',
                                 user: user).sole).to include(is_local: true, catalog_id: book.id, in_library: true)
  end

  it 'keeps ambiguous existing works searchable but refuses to create another duplicate' do
    2.times { Book.create!(title: 'Witchwolf', author: 'Sam Burns & W.M. Fawkes') }
    data = BookProviderMetadata.apple(audio).with_indifferent_access
    expect(DiscoveryResults.call([data], 'book').sole[:is_local]).to be false
    expect { ShelfCatalogImport.call(Book, data) }.to raise_error(MetadataImport::Invalid, /Several matching works/)
    expect(Book.count).to eq(2)
  end

  it 'never substitutes a different author and never changes a work date on edition refresh' do
    original = Book.create!(title: 'Witchwolf', author: 'Another Writer', release_year: 2000)
    data = BookProviderMetadata.apple(audio).with_indifferent_access
    expect(BookCatalogIdentity.existing(data)).to be_nil
    original.update!(api_id: 'itunes_6786439611')
    stub_request(:get, 'https://itunes.apple.com/lookup?id=6786439611').to_return(body: { results: [audio] }.to_json)
    fields, = MetadataProvider.new(original).call
    expect(fields).not_to have_key(:release_year)
    expect(original.reload.release_year).to eq(2000)
  end
end
