# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PublicShelfMembership do
  it 'matches exact type and ID, caps results and exposes public selection fields only' do
    owner = User.create!(confirmed_at: Time.current, name: 'Curator', username: 'curator', email: 'curator@example.com',
                         password: 'password')
    movie = Movie.create!(title: 'A film')
    book = Book.create!(title: 'A book')
    owner.shelf_collections.create!(title: 'Books', picks: [{ type: 'Book', id: book.id }])
    shelf = owner.shelf_collections.create!(title: 'Films', picks: [{ type: 'Movie', id: movie.id }])
    owner.favorite_shelves.create!(category: 'Movie', picks: [{ type: 'Movie', id: movie.id }])
    expect(described_class.call(movie)).to eq([])
    owner.shelf_previews.attach(io: File.open(Rails.root.join('spec/fixtures/files/comic-portrait.png')),
                                filename: 'preview.png', content_type: 'image/png')
    results = described_class.call(movie)
    expect(results.map { |result| result[:title] }).to contain_exactly('Movies')
    expect(results.first.keys).to contain_exactly(:title, :creator, :url, :count, :covers)
    expect(results.first[:url]).to include('category=Movie')
    expect(results.map { |result| result[:url] }).not_to include("collection=#{shelf.slug}")
    expect(results.first[:covers].first.keys).to contain_exactly(:title, :type, :cover)
    expect(described_class.call(movie, limit: 1).size).to eq(1)
    owner.favorite_shelves.find_by!(category: 'Movie').update!(picks: [{ type: 'Movie', id: movie.id.to_s }])
    expect(described_class.call(movie).size).to eq(1)
    stub_const('PublicShelfMembership::CANDIDATE_LIMIT', 1)
    owner.favorite_shelves.create!(category: 'Book', picks: [{ type: 'Book', id: book.id }])
    expect(described_class.call(movie)).to eq([])
    owner.update!(confirmed_at: nil)
    expect(described_class.call(movie)).to eq([])
    owner.update!(confirmed_at: Time.current, username: nil)
    expect(described_class.call(movie)).to eq([])
  end

  it 'discovers named shelves only after a specific current preview was published' do
    owner = User.create!(confirmed_at: Time.current, name: 'Named curator', username: 'named_curator',
                         email: 'named-curator@example.com', password: 'password')
    movie = Movie.create!(title: 'Named shelf film')
    shelf = owner.shelf_collections.create!(title: 'A shared named shelf', picks: [{ type: 'Movie', id: movie.id }])
    publish = lambda do |category, signature|
      owner.shelf_previews.attach(io: File.open(Rails.root.join('spec/fixtures/files/comic-portrait.png')),
                                  filename: 'preview.png', content_type: 'image/png',
                                  metadata: { category: category, signature: signature })
    end
    publish.call('overview', 'unrelated')
    expect(described_class.call(movie)).to eq([])
    publish.call("collection:#{shelf.slug}", 'stale')
    expect(described_class.call(movie)).to eq([])
    publish.call("collection:#{shelf.slug}", ShelfCollectionPreviewSignature.call(shelf))
    result = described_class.call(movie).first
    expect(result[:title]).to eq(shelf.title)
    expect(result[:url]).to include("collection=#{shelf.slug}")
    shelf.update!(description: 'Changed and not yet republished')
    expect(described_class.call(movie)).to eq([])
    publish.call("collection:#{shelf.slug}", ShelfCollectionPreviewSignature.call(shelf))
    expect(described_class.call(movie).size).to eq(1)
    shelf.update_column(:archived_at, Time.current)
    expect(described_class.call(movie)).to eq([])
    shelf.update_column(:archived_at, nil)
    expect(described_class.call(movie).size).to eq(1)
    owner.update!(confirmed_at: nil)
    expect(described_class.call(movie)).to eq([])
  end

  it 'uses fixed query batches without loading preview objects for six favorite shelves' do
    movie = Movie.create!(title: 'Batch sample')
    6.times do |index|
      owner = User.create!(confirmed_at: Time.current, name: "Batch #{index}", username: "batch_#{index}",
                           email: "batch#{index}@example.com", password: 'password')
      owner.favorite_shelves.create!(category: 'Movie', picks: [{ type: 'Movie', id: movie.id }])
      owner.shelf_previews.attach(io: File.open(Rails.root.join('spec/fixtures/files/comic-portrait.png')),
                                  filename: 'preview.png', content_type: 'image/png')
    end
    queries = []
    subscriber = lambda do |*, payload|
      queries << payload[:sql] unless payload[:name] == 'SCHEMA' || payload[:cached]
    end
    results = nil
    ApplicationRecord.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
        results = described_class.call(movie, limit: 6)
      end
    end
    expect(results.size).to eq(6)
    expect(queries.size).to be <= 7
    expect(queries.grep(/SELECT "active_storage_blobs"\.\*/)).to be_empty
    warn "Shelf membership SQL count for six same-type favorites: #{queries.size}"
  end
end
