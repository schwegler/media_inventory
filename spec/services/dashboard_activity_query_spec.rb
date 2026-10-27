# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardActivityQuery do
  let(:owner) { User.create!(name: 'Reader', email: 'reader@example.test', password: 'password123') }
  let(:movie) { Movie.create!(title: 'A discovery') }

  it 'deduplicates in SQL before the limit without loading repeated events' do
    entry = LibraryItem.create!(user: owner, item: movie)
    Activity.insert_all!(1000.times.map do
      { user_id: owner.id, trackable_type: 'LibraryItem', trackable_id: entry.id, activity_type: 'added' }
    end)
    9.times do |i|
      item = Movie.create!(title: "Other #{i}")
      Activity.create!(user: owner, trackable: item, activity_type: 'added')
    end
    instantiated = 0
    callback = lambda do |*args|
      data = args.last
      instantiated += data[:record_count] if data[:class_name] == 'Activity'
    end
    results = nil
    ActiveSupport::Notifications.subscribed(callback, 'instantiation.active_record') do
      results = described_class.new(Activity.all).latest(limit: 9).to_a
    end
    expect(results.size).to eq(9)
    expect(instantiated).to eq(9)
  end

  it 'excludes another owner’s false and NULL reviews including direct-media activities' do
    entry = LibraryItem.create!(user: owner, item: movie, review: 'Private words', rating: '4.5', is_public: false)
    activity = Activity.create!(user: owner, trackable: movie, activity_type: 'reviewed')
    expect(described_class.new(Activity.all).latest(limit: 9)).to be_empty
    expect(described_class.new(Activity.all, viewer_id: owner.id).latest(limit: 9)).to include(activity)
    entry.update!(is_public: nil)
    expect(described_class.new(Activity.all).latest(limit: 9)).to be_empty
    entry.update!(is_public: true)
    results = described_class.new(Activity.all).latest(limit: 9, reviews_only: true).to_a
    described_class.attach_review_entries(results)
    expect(results.first.trackable).to eq(entry)
  end

  it 'never selects a private legacy duplicate when resolving a public direct review' do
    LibraryItem.create!(user: owner, item: movie, review: 'Hidden duplicate', is_public: false)
    public_entry = LibraryItem.new(user: owner, item: movie, review: 'Public review', is_public: true)
    public_entry.save!(validate: false)
    Activity.create!(user: owner, trackable: movie, activity_type: 'reviewed')
    results = described_class.new(Activity.all).latest(limit: 3, reviews_only: true).to_a
    described_class.attach_review_entries(results)
    expect(results.first.trackable).to eq(public_entry)
  end

  it 'groups proxies and direct events before limiting popularity and skips orphan titles' do
    entry = LibraryItem.create!(user: owner, item: movie)
    Activity.create!(user: owner, trackable: entry, activity_type: 'added')
    Activity.create!(user: owner, trackable: movie, activity_type: 'consumed')
    orphan = Movie.create!(title: 'Deleted')
    Activity.create!(user: owner, trackable: orphan, activity_type: 'added')
    orphan.delete
    expect(described_class.new(Activity.all).popular(limit: 1)).to eq({ ['Movie', movie.id] => 2 })
  end

  it 'batch attaches review entries across multiple direct activities in minimal queries' do
    m1 = Movie.create!(title: 'Movie 1')
    m2 = Movie.create!(title: 'Movie 2')
    entry1 = LibraryItem.create!(user: owner, item: m1, review: 'Great 1', is_public: true)
    entry2 = LibraryItem.create!(user: owner, item: m2, review: 'Great 2', is_public: true)
    act1 = Activity.create!(user: owner, trackable: m1, activity_type: 'reviewed')
    act2 = Activity.create!(user: owner, trackable: m2, activity_type: 'reviewed')
    act3 = Activity.create!(user: owner, trackable: movie, activity_type: 'consumed')

    described_class.attach_review_entries([act1, act2, act3])

    expect(act1.trackable).to eq(entry1)
    expect(act2.trackable).to eq(entry2)
  end
end
