# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaCardRatings do
  let(:viewer) { User.create!(name: 'Viewer', email: 'ratings-viewer@example.com', password: 'password123') }
  let(:other) { User.create!(name: 'Other', email: 'ratings-other@example.com', password: 'password123') }
  let(:movie) { Movie.create!(title: 'Ratings') }

  def insert_rating(item, rating, user: other, public: true, review: nil)
    LibraryItem.insert_all!([{ item_type: item.class.polymorphic_name, item_id: item.id,
                               user_id: user.id, rating: rating, is_public: public, review: review }])
  end

  def ratings(item = movie, user_id: nil)
    described_class.call([item], user_id: user_id).fetch(described_class.key(item, user_id))
  end

  def measured_call(items, user_id: nil)
    queries = []
    instantiated = 0
    sql = lambda do |*, payload|
      queries << payload[:sql] if payload[:sql].match?(/SELECT.*library_items/i)
    end
    instantiate = ->(*, payload) { instantiated += payload[:record_count] if payload[:class_name] == 'LibraryItem' }
    result = nil
    ActiveSupport::Notifications.subscribed(instantiate, 'instantiation.active_record') do
      ActiveSupport::Notifications.subscribed(sql, 'sql.active_record') do
        result = described_class.call(items, user_id: user_id)
      end
    end
    [result, queries, instantiated]
  end

  it 'excludes private and NULL-visibility entries for a guest' do
    insert_rating(movie, '4.0')
    insert_rating(movie, '1.0', public: false)
    insert_rating(movie, '2.0', public: nil)
    expect(ratings).to eq(user_rating: nil, avg_rating: 4.0)
  end

  it 'includes only the viewer own private rating alongside public ratings' do
    insert_rating(movie, '4.0')
    insert_rating(movie, '1.0', public: false)
    insert_rating(movie, '5.0', user: viewer, public: false)
    expect(ratings(user_id: viewer.id)).to eq(user_rating: '5.0', avg_rating: 4.5)
  end

  it 'includes a viewer entry with NULL visibility and does not double count public own entries' do
    insert_rating(movie, '3.0', user: viewer, public: nil)
    insert_rating(movie, '5.0')
    expect(ratings(user_id: viewer.id)).to eq(user_rating: '3.0', avg_rating: 4.0)
    LibraryItem.where(user_id: viewer.id).update_all(is_public: true)
    expect(ratings(user_id: viewer.id)).to eq(user_rating: '3.0', avg_rating: 4.0)
  end

  it 'preserves Ruby present? and to_f behavior for legacy string ratings' do
    values = [nil, '', ' ', "\t", '4.0', '3.25', '2.5 stars', 'bad', '1e0', '1_0', '0', '-1.0']
    values.each { |value| insert_rating(movie, value) }
    expected = values.filter_map { |value| value.to_f if value.present? }
    expect(ratings[:avg_rating]).to eq((expected.sum / expected.size).round(1))
  end

  it 'returns nil for an entirely unrated item including an unrated viewer entry' do
    insert_rating(movie, '', user: viewer, public: false)
    insert_rating(movie, nil)
    expect(ratings(user_id: viewer.id)).to eq(user_rating: nil, avg_rating: nil)
  end

  it 'preserves compensated summation for cancelling legacy floats' do
    %w[1e16 1.0 -1e16].each { |rating| insert_rating(movie, rating) }
    expect(ratings[:avg_rating]).to eq(0.3)
  end

  it 'counts duplicate legacy entries in the average and picks the first own entry' do
    insert_rating(movie, '2.0', user: viewer)
    insert_rating(movie, '4.0', user: viewer)
    expect(ratings(user_id: viewer.id)).to eq(user_rating: '2.0', avg_rating: 3.0)
  end

  it 'keeps polymorphic types separate when their numeric ids coincide' do
    game = VideoGame.create!(id: movie.id, title: 'Game', game_type: 'game')
    insert_rating(movie, '4.0')
    insert_rating(game, '2.0')
    result = described_class.call([movie, game])
    expect(result.fetch(described_class.key(movie, nil))[:avg_rating]).to eq(4.0)
    expect(result.fetch(described_class.key(game, nil))[:avg_rating]).to eq(2.0)
  end

  it 'keeps queries constant as the number of cards grows within a page' do
    movies = (1..24).map { |number| Movie.create!(title: "Card #{number}") }
    movies.each { |item| insert_rating(item, '4.0') }
    small, small_queries, = measured_call(movies.first(1))
    large, large_queries, instantiated = measured_call(movies)
    expect(small.size).to eq(1)
    expect(large.size).to eq(24)
    expect(large_queries.size).to eq(small_queries.size)
    expect(large_queries.size).to eq(2)
    expect(instantiated).to eq(0)
    expect(movies).to all(satisfy { |item| !item.association(:library_items).loaded? })
  end

  it 'keeps standard high-fanout ratings aggregated without owner object allocations or review columns' do
    insert_rating(movie, '4.0', review: 'x' * 4096)
    measured_call([movie]) # warm caches before measuring allocations
    before = GC.stat(:total_allocated_objects)
    _, small_queries, = measured_call([movie])
    small_allocations = GC.stat(:total_allocated_objects) - before
    row = { item_type: 'Movie', item_id: movie.id, user_id: other.id,
            rating: '4.0', is_public: true, review: 'x' * 4096 }
    4.times { LibraryItem.insert_all!(Array.new(250) { row.dup }) }
    before = GC.stat(:total_allocated_objects)
    result, queries, instantiated = measured_call([movie])
    allocations = GC.stat(:total_allocated_objects) - before
    expect(result.values).to eq([{ user_rating: nil, avg_rating: 4.0 }])
    expect(queries.size).to eq(small_queries.size)
    expect(queries.size).to eq(2)
    expect(allocations).to be < small_allocations + 1000
    expect(instantiated).to eq(0)
    expect(queries.join).not_to match(/SELECT\s+"library_items"\.\*|"review"/)
  end

  it 'batches the viewer rating query across all cards as well' do
    movies = (1..24).map { |number| Movie.create!(title: "Personal #{number}") }
    movies.each { |item| insert_rating(item, '3.5', user: viewer, public: false) }
    _, small_queries, = measured_call(movies.first(1), user_id: viewer.id)
    result, queries, instantiated = measured_call(movies, user_id: viewer.id)
    expect(queries.size).to eq(small_queries.size)
    expect(queries.size).to eq(3)
    expect(result.values).to all(eq(user_rating: '3.5', avg_rating: 3.5))
    expect(instantiated).to eq(0)
  end

  it 'streams nonstandard ratings beyond one batch without instantiating owners' do
    row = { item_type: 'Movie', item_id: movie.id, user_id: other.id,
            rating: '2.25 stars', is_public: true }
    LibraryItem.insert_all!(Array.new(described_class::BATCH_SIZE + 1) { row.dup })
    result, queries, instantiated = measured_call([movie])
    expect(result.values).to eq([{ user_rating: nil, avg_rating: 2.3 }])
    expect(instantiated).to eq(0)
    expect(queries.grep(/LIMIT/).size).to be >= 2
    expect(movie.association(:library_items)).not_to be_loaded
  end

  it 'supports rated child media without a reverse library_items association' do
    show = TvShow.create!(title: 'Series')
    episode = show.tv_episodes.create!(name: 'Episode', season: 1, episode: 1)
    insert_rating(episode, '4.5')
    expect(ratings(episode)).to eq(user_rating: nil, avg_rating: 4.5)
  end
end
