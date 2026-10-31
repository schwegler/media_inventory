# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Edition chapters and progress', type: :request do
  let!(:owner) do
    User.create!(name: 'Reader', email: 'edition-reader@example.com', password: 'password123', confirmed_at: Time.current)
  end
  let!(:book) { Book.create!(title: 'Synthetic novel', author: 'Writer', release_year: 1999) }
  let!(:library) { LibraryItem.create!(user: owner, item: book, rating: 4) }

  before { post login_path, params: { session: { email: owner.email, password: 'password123' } } }

  def add_edition(format: 'ebook', chapters: "Prologue\nPart I | 1 | Arrival\nPart II | Epilogue | Home")
    post book_book_editions_path(book),
         params: {
           book_edition: { label: "Synthetic #{format}", format: format,
                           structure_kind: format == 'audiobook' ? 'audio_segments' : 'chapters',
                           complete_chapter_list: '1' }, chapters: chapters
         }
    expect(response).to have_http_status(:redirect)
    book.book_editions.order(:id).last
  end

  it 'does not duplicate manual editions or chapter identities on a repeated submission' do
    edition = add_edition
    ids = edition.book_chapters.ordered.pluck(:id)
    expect(add_edition).to eq(edition)
    expect(book.book_editions.count).to eq(1)
    expect(edition.book_chapters.ordered.pluck(:id)).to eq(ids)
  end

  it 'attaches a selected audio edition even when the work is already in this library' do
    library.update!(review: 'Keep this work review')
    data = BookProviderMetadata.apple({ 'collectionId' => 123, 'collectionName' => book.title,
                                        'artistName' => book.author, 'releaseDate' => '2025-10-28' })
    data = DiscoveryResults.call([data], 'book', user: owner).sole
    token = MetadataImport.sign('book', data)
    2.times { post books_path, params: { discovery: '1', book: { import_selection: token } } }
    expect(response).to redirect_to(book)
    expect(Book.count).to eq(1)
    expect(book.book_editions.sole).to have_attributes(format: 'audiobook', published_on: Date.new(2025, 10, 28))
    expect(library.reload.review).to eq('Keep this work review')
    expect(book.reload.release_year).to eq(1999)
  end

  it 'preserves prologues, parts and stable reviewed IDs through partial or conflicting refreshes' do
    edition = add_edition
    chapter = edition.book_chapters.ordered.first
    review = LibraryItem.create!(user: owner, item: chapter, review: 'The opening', is_public: true)
    ids = edition.book_chapters.ordered.pluck(:id)
    expect(BookChapterLists.reconcile(edition, [])).to eq(0)
    same = { identity_key: chapter.identity_key, position: 0, title: 'Changed title' }
    expect(BookChapterLists.reconcile(edition, [same])).to eq(0)
    expect do
      BookChapterLists.reconcile(edition, [{ identity_key: 'different', position: 0, title: 'Other' }])
    end.to raise_error(BookChapterLists::Conflict)
    expect(edition.book_chapters.ordered.pluck(:id)).to eq(ids)
    expect(chapter.reload.title).to eq('Prologue')
    expect(review.reload.item_id).to eq(chapter.id)
    patch book_book_edition_path(book, edition), params: { chapters: 'Replacement' }
    expect(edition.book_chapters.ordered.pluck(:id)).to eq(ids)
    expect(edition.book_chapters.ordered.last.part).to eq('Part II')
  end

  it 'keeps reading/listening passes separate, retries idempotent, and parent completion independent' do
    first = add_edition
    audio = add_edition(format: 'audiobook')
    2.times { post book_reading_passes_path, params: { book_edition_id: first.id, previous_number: 0 } }
    pass = library.book_reading_passes.sole
    chapter = first.book_chapters.ordered.first
    2.times { patch book_reading_pass_path(pass), params: { chapter_id: chapter.id, completed: true } }
    expect(pass.book_chapter_completions.count).to eq(1)
    patch book_reading_pass_path(pass), params: { chapter_id: audio.book_chapters.first.id, completed: true }
    expect(response).to have_http_status(:not_found)
    post book_reading_passes_path, params: { book_edition_id: audio.id, previous_number: 0 }
    expect(library.book_reading_passes.find_by(book_edition: audio).book_chapter_completions).to be_empty
    post book_reading_passes_path, params: { book_edition_id: first.id, previous_number: 1 }
    expect(library.book_reading_passes.where(book_edition: first).count).to eq(2)
    expect(pass.reload.book_chapter_completions.count).to eq(1)
    expect(library.reload).not_to be_consumed
    expect(library.rating).to eq('4')
    expect(ConsumptionPass.count).to eq(0)
    expect(owner.library_items.where(item_type: 'BookChapter')).to be_empty
  end

  it 'shows unknown progress without leaking other users passes and permits filling an empty edition once' do
    edition = add_edition(chapters: nil)
    get book_path(book)
    expect(response.body).to include('Progress is unknown')
    patch book_book_edition_path(book, edition), params: { chapters: 'A chapter', complete_chapter_list: false }
    expect(edition.book_chapters.count).to eq(1)
    post book_reading_passes_path, params: { book_edition_id: edition.id, previous_number: 0 }
    other = User.create!(name: 'Other', email: 'edition-other@example.com', password: 'password123',
                         confirmed_at: Time.current)
    post login_path, params: { session: { email: other.email, password: 'password123' } }
    get book_path(book)
    expect(response.body).not_to include('Pass 1', 'of 1 known')
    patch book_reading_pass_path(library.book_reading_passes.sole),
          params: { chapter_id: edition.book_chapters.first.id, completed: true }
    expect(response).to have_http_status(:not_found)
    post book_book_editions_path(book), params: { book_edition: { label: 'Other edition', format: 'ebook' } }
    expect(response).to have_http_status(:forbidden)
  end

  it 'keeps chapter review navigation inside its edition and shows same-author chapter reviews on the work' do
    edition = add_edition
    audio = add_edition(format: 'audiobook')
    library.update!(review: 'Work review', is_public: true)
    entries = edition.book_chapters.ordered.map do |c|
      LibraryItem.create!(user: owner, item: c, review: c.title, is_public: true)
    end
    alien = LibraryItem.create!(user: owner, item: audio.book_chapters.first, review: 'Audio secret', is_public: false)
    get public_review_path(entries.first)
    expect(response.body).to include(public_review_path(entries[1]), public_review_path(library))
    get public_review_path(library)
    expect(response.body).to include(public_review_path(alien)) # owner can see own private review
    delete logout_path
    get public_review_path(library)
    expect(response.body).not_to include(public_review_path(alien), 'Audio secret', 'Synthetic audiobook')
    get public_review_path(entries.first)
    expect(response.body).not_to include(public_review_path(alien))
  end
end
