# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LandingController, type: :controller do
  let!(:viewer) { User.create!(name: 'Viewer', email: 'viewer@example.com', password: 'password123') }
  let!(:friend) { User.create!(name: 'Friend', email: 'friend@example.com', password: 'password123') }
  let!(:movie) { Movie.create!(title: 'Repeated title') }
  let!(:entry) { LibraryItem.create!(user: friend, item: movie) }

  def activity(trackable, type: 'added', user: friend)
    Activity.create!(user: user, trackable: trackable, activity_type: type)
  end

  before { allow(controller).to receive(:current_user).and_return(viewer) }

  it 'keeps the latest event per person and title, including direct media events' do
    activity(entry)
    activity(movie, type: 'consumed')
    latest = activity(entry, type: 'reviewed')
    other_person = activity(movie, user: viewer)

    results = controller.send(:unique_dashboard_activities, controller.send(:dashboard_activity_scope), limit: 9)
    expect(results).to eq([other_person, latest])
  end

  it 'fills the grid with unique activities before applying the limit' do
    older = 9.times.map do |i|
      activity(LibraryItem.create!(user: friend, item: Movie.create!(title: "Discovery #{i}")))
    end
    105.times { activity(entry) }

    results = controller.send(:fetch_friend_activities)
    expect(results.size).to eq(9)
    expect(results.map(&:trackable)).to include(entry, older.last.trackable)
  end

  it 'aggregates popularity across library entries and direct activity for one title' do
    second_entry = LibraryItem.create!(user: viewer, item: movie)
    other_movie = Movie.create!(title: 'Other title')
    activity(entry)
    activity(second_entry)
    activity(movie)
    2.times { activity(other_movie) }

    expect(controller.send(:fetch_popular_items)).to eq([movie, other_movie])
  end

  it 'deduplicates popular fallback titles' do
    entry.update!(is_public: true)
    LibraryItem.create!(user: viewer, item: movie, is_public: true)
    Activity.delete_all

    expect(controller.send(:fetch_popular_items)).to eq([movie])
  end

  it 'keeps one review per person and title and skips missing reviews' do
    entry.update!(review: 'A good film')
    activity(entry, type: 'reviewed')
    latest = activity(entry, type: 'reviewed')
    blank = LibraryItem.create!(user: friend, item: Movie.create!(title: 'No review'))
    activity(blank, type: 'reviewed')

    expect(controller.send(:fetch_popular_reviews)).to eq([latest])
  end
end
