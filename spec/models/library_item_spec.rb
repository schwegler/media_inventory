# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LibraryItem, type: :model do
  it 'is valid with valid attributes' do
    user = User.create!(name: 'Test', email: "test_#{SecureRandom.hex(4)}@test.com", password: 'password',
                        password_confirmation: 'password')
    album = Album.create!(title: 'Test Album')
    item = LibraryItem.new(user: user, item: album)
    expect(item).to be_valid
  end
  it 'posts an existing review when it becomes public, without reposting unrelated edits' do
    user = User.create!(name: 'Reader', password: 'password')
    movie = Movie.create!(title: 'A film')
    entry = LibraryItem.create!(user: user, item: movie, review: 'Good film', is_public: false)
    allow(SocialPostJob).to receive(:perform_later)

    entry.update!(is_public: true)
    expect(SocialPostJob).to have_received(:perform_later).with(entry, 'reviewed').once

    entry.update!(consumed_at: Date.current)
    expect(SocialPostJob).to have_received(:perform_later).with(entry, 'reviewed').once
  end

  describe 'marking series watched' do
    let(:user) { User.create!(name: 'Viewer', password: 'password') }
    let(:tv_show) { TvShow.create!(title: 'Better Call Saul') }
    let!(:ep1) { tv_show.tv_episodes.create!(name: 'Uno', season: 1, episode: 1) }
    let!(:ep2) { tv_show.tv_episodes.create!(name: 'Mijo', season: 1, episode: 2) }
    let!(:ep3) { tv_show.tv_episodes.create!(name: 'Switch', season: 2, episode: 1) }

    it 'marks all episodes watched when the TV show library item is marked watched' do
      LibraryItem.create!(user: user, item: ep1, consumed: true, consumed_at: 1.month.ago.to_date,
                          rating: '4.5', review: 'Great start!')

      show_lib = LibraryItem.create!(user: user, item: tv_show, consumed: false)
      show_lib.update!(consumed: true)

      expect(user.library_items.find_by(item: ep1).consumed).to be(true)
      expect(user.library_items.find_by(item: ep1).rating).to eq('4.5')
      expect(user.library_items.find_by(item: ep1).review).to eq('Great start!')
      expect(user.library_items.find_by(item: ep1).consumed_at).to eq(1.month.ago.to_date)

      expect(user.library_items.find_by(item: ep2).consumed).to be(true)
      expect(user.library_items.find_by(item: ep3).consumed).to be(true)
    end

    it 'marks all episodes watched when the TV show library item is created with consumed: true' do
      LibraryItem.create!(user: user, item: tv_show, consumed: true)

      expect(user.library_items.find_by(item: ep1).consumed).to be(true)
      expect(user.library_items.find_by(item: ep2).consumed).to be(true)
      expect(user.library_items.find_by(item: ep3).consumed).to be(true)
    end

    it 'marks newly imported episodes watched if the series is already watched by the user' do
      LibraryItem.create!(user: user, item: tv_show, consumed: true)

      MetadataChildren.episodes(
        tv_show,
        [{ 'name' => 'Cobbler', 'season' => 2, 'number' => 2, 'airdate' => '2016-02-22' }]
      )

      ep4 = tv_show.tv_episodes.find_by(season: 2, episode: 2)
      expect(ep4).to be_present
      expect(user.library_items.find_by(item: ep4)&.consumed).to be(true)
    end
  end
end
