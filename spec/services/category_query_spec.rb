# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CategoryQuery do
  it 'pages in SQL and instantiates only the requested display records' do
    entity = MetadataEntity.create!(name: 'Shared director', kind: 'person')
    movies = 55.times.map { |i| Movie.create!(title: format('Film %02d', i), release_year: 2000 + i) }
    movies.each { |movie| MetadataCredit.create!(item: movie, metadata_entity: entity, role: 'Director', source: 'manual') }
    instantiated = 0
    callback = lambda do |*args|
      payload = args.last
      instantiated += payload[:record_count] if payload[:class_name] == 'Movie'
    end
    query = described_class.new('directors')
    result = nil
    ActiveSupport::Notifications.subscribed(callback, 'instantiation.active_record') do
      result = query.items('Shared director', sort: 'title', page: 2)
    end
    expect(result.map(&:title)).to eq(movies[24, 24].map(&:title))
    expect(result.total_count).to eq(55)
    expect(result.current_page).to eq(2)
    expect(query.media_counts.values_at('all', 'movies')).to eq([55, 55])
    expect(instantiated).to eq(24)
  end

  it 'matches exact legacy tokens across separators and deduplicates creator roles' do
    comic = Comic.create!(title: 'One work', writer: 'Alex Ross', artist: 'alex ross; Other / A|B')
    comic.metadata_credits.delete_all
    query = described_class.new('comic-creators')
    expect(query.items('Alex Ross').to_a).to eq([comic])
    expect(query.items('Alex').to_a).to be_empty
    expect(query.items("Alex Ross') OR 1=1 --").to_a).to be_empty
    expect(query.categories(query: "%' OR 1=1 --")).to be_empty
    expect { described_class.new('actors; DROP TABLE movies') }.to raise_error(ArgumentError)
    list = query.categories(sort: 'name')
    expect(list.find { |entry| entry.name == 'Alex Ross' }.count).to eq(1)
    expect(list.map(&:name)).to include('Other', 'A', 'B')
  end

  it 'keeps polymorphic ids separate and counts child credits without duplicate roles' do
    entity = MetadataEntity.create!(name: 'A creator', kind: 'person')
    show = TvShow.create!(title: 'Series')
    episode = show.tv_episodes.create!(season: 1, episode: 1, name: 'Pilot')
    %w[Writer Screenwriter].each do |role|
      MetadataCredit.create!(item: episode, metadata_entity: entity, role: role, source: 'manual')
    end
    book = Book.create!(title: 'Novel', author: 'A creator')
    query = described_class.new('writers')
    expect(query.items('A creator').to_a).to match_array([episode, book])
    expect(query.items('A creator', media_type: 'tv_shows').to_a).to eq([episode])
    expect(query.media_counts.values_at('all', 'tv_shows', 'books')).to eq([2, 1, 1])
  end

  it 'escapes wildcard inputs, preserves Unicode and returns paginated names' do
    books = 51.times.map { |i| Book.create!(title: "Book #{i}", author: format('Élodie %02d', i)) }
    books.each { |book| book.metadata_credits.delete_all }
    query = described_class.new('authors')
    names = query.categories(query: 'élodie', page: 2, per: 48, sort: 'name')
    expect(names.size).to eq(3)
    expect(names.total_count).to eq(51)
    expect(query.categories(query: '%').size).to eq(0)
    expect(query.items('Élodie 50').to_a).to eq([books.last])
  end
end
