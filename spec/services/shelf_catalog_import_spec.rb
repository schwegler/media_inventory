# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShelfCatalogImport do
  def selection(id, title = 'Provider discovery')
    { title: title, api_id: id }.with_indifferent_access
  end

  it 'reuses the first existing duplicate without changing either record' do
    first = Book.create!(title: 'Original', api_id: 'openlibrary_existing')
    duplicate = Book.create!(title: 'Existing duplicate', api_id: 'openlibrary_existing')
    expect do
      expect(described_class.call(Book, selection('openlibrary_existing'))).to eq(first)
    end.not_to change(Book, :count)
    expect(duplicate.reload.title).to eq('Existing duplicate')
  end

  it 'does not merge different provider identities merely because titles match' do
    first = described_class.call(Book, selection('openlibrary_one'))
    second = described_class.call(Book, selection('openlibrary_two'))
    expect(first.id).not_to eq(second.id)
  end

  it 'rejects URL-only game imports before they can create duplicate records' do
    data = { title: 'URL-only game', external_url: 'https://games.example/one' }.with_indifferent_access
    expect do
      expect { described_class.call(VideoGame, data) }.to raise_error(MetadataImport::Invalid, /stable provider ID/)
    end.not_to change(VideoGame, :count)
  end

  it 'rejects external results without a stable identity and reuses signed URL identities' do
    expect do
      described_class.call(Book, { title: 'No identity' }.with_indifferent_access)
    end.to raise_error(MetadataImport::Invalid, /stable provider identity/)
    data = { title: 'URL identity', external_url: 'https://catalog.example/books/one' }.with_indifferent_access
    expect(described_class.call(Book, data).id).to eq(described_class.call(Book, data).id)
  end
end

RSpec.describe 'Concurrent shelf catalog imports' do
  self.use_transactional_tests = false

  before { @provider_id = "openlibrary_concurrent_#{SecureRandom.hex(8)}" }

  after do
    Book.where(api_id: @provider_id).delete_all
    ShelfCatalogIdentity.where(provider_id: @provider_id).delete_all
  end

  it 'serializes two database connections without requiring catalog uniqueness' do
    ready = Queue.new
    start = Queue.new
    workers = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          ShelfCatalogImport.call(Book, { title: 'Concurrent discovery', api_id: @provider_id }
                                        .with_indifferent_access).id
        end
      end
    end
    Timeout.timeout(10) { 2.times { ready.pop } }
    2.times { start << true }
    ids = Timeout.timeout(20) { workers.map(&:value) }
    expect(ids.uniq.size).to eq(1)
    expect(Book.where(api_id: @provider_id).count).to eq(1)
    expect(ShelfCatalogIdentity.where(provider_id: @provider_id).count).to eq(1)
  ensure
    workers&.each { |worker| worker.kill if worker.alive? }
  end
end
