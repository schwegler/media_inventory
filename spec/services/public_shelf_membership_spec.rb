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
    owner.update!(username: nil)
    expect(described_class.call(movie)).to eq([])
  end
end
