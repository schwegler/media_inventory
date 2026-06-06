# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Activity, type: :model do
  let(:user) do
    User.create!(name: 'Andrew', email: 'andrew@example.com', password: 'password123', password_confirmation: 'password123')
  end

  describe 'callbacks' do
    it 'creates an added activity when media is created with is_collected: true' do
      expect do
        Movie.create!(title: 'Buffy the Vampire Slayer', user: user, is_collected: true)
      end.to change(Activity.where(activity_type: 'added'), :count).by(1)
    end

    it 'creates a watchlist activity when media is created with in_watchlist: true' do
      expect do
        Movie.create!(title: 'Buffy the Vampire Slayer', user: user, in_watchlist: true, is_collected: false)
      end.to change(Activity.where(activity_type: 'watchlist'), :count).by(1)
    end

    it 'creates a consumed activity when media is marked as consumed' do
      expect do
        Album.create!(title: '7 Songs', artist: 'Fugazi', user: user, consumed: true)
      end.to change(Activity.where(activity_type: 'consumed'), :count).by(1)
    end

    it 'creates a reviewed activity when media is created with review' do
      expect do
        TvShow.create!(title: 'Buffy the Vampire Slayer', season: 1, episode: 4, user: user, review: 'Amazing show!',
                       rating: '5')
      end.to change(Activity.where(activity_type: 'reviewed'), :count).by(1)
    end
  end

  describe '#description' do
    it 'formats tv show reviewed activity correctly' do
      show = TvShow.create!(title: 'Buffy the Vampire Slayer', season: 1, episode: 4, user: user, review: 'Great S1E04!',
                            rating: '5')
      activity = show.activities.find_by(activity_type: 'reviewed')
      expect(activity.description).to eq("Andrew reviewed S1E04 of 'Buffy the Vampire Slayer' (Rating: 5)")
    end
  end
end
