# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InProgressTracker do
  let!(:user) do
    User.create!(name: 'Tracker User', email: 'tracker@example.com', password: 'password123',
                 password_confirmation: 'password123', confirmed_at: Time.current)
  end

  let!(:tv_show) { TvShow.create!(title: 'Parks and Recreation') }
  let!(:show_lib) { LibraryItem.create!(user: user, item: tv_show, is_public: true) }

  let!(:s1e1) { tv_show.tv_episodes.create!(name: 'Pilot', season: 1, episode: 1) }
  let!(:s1e2) { tv_show.tv_episodes.create!(name: 'Canvassing', season: 1, episode: 2) }
  let!(:s1e3) { tv_show.tv_episodes.create!(name: 'The Reporter', season: 1, episode: 3) }
  let!(:s2e1) { tv_show.tv_episodes.create!(name: 'Pawnee Zoo', season: 2, episode: 1) }

  let!(:comic) { Comic.create!(title: 'Saga') }
  let!(:comic_lib) { LibraryItem.create!(user: user, item: comic, is_public: true) }

  let!(:issue1) { comic.comic_issues.create!(issue_number: 1, title: 'Chapter One') }
  let!(:issue2) { comic.comic_issues.create!(issue_number: 2, title: 'Chapter Two') }
  let!(:issue3) { comic.comic_issues.create!(issue_number: 3, title: 'Chapter Three') }

  describe '.items_for' do
    context 'when no episodes or issues are consumed' do
      it 'returns an empty array' do
        expect(described_class.items_for(user)).to be_empty
      end
    end

    context 'when some episodes are consumed' do
      before do
        LibraryItem.create!(user: user, item: s1e1, consumed: true, consumed_at: Date.current)
      end

      it 'returns the TV show as in-progress with the next episode' do
        items = described_class.items_for(user)
        expect(items.size).to eq(1)

        item = items.first
        expect(item.series).to eq(tv_show)
        expect(item.media_type).to eq('TvShow')
        expect(item.completed_count).to eq(1)
        expect(item.total_count).to eq(4)
        expect(item.percent).to eq(25)
        expect(item.next_item).to eq(s1e2)
      end

      it 'advances to next season when a season is finished' do
        LibraryItem.create!(user: user, item: s1e2, consumed: true, consumed_at: Date.current)
        LibraryItem.create!(user: user, item: s1e3, consumed: true, consumed_at: Date.current)

        items = described_class.items_for(user)
        expect(items.size).to eq(1)
        expect(items.first.completed_count).to eq(3)
        expect(items.first.next_item).to eq(s2e1)
      end

      it 'excludes the show when all episodes are consumed' do
        LibraryItem.create!(user: user, item: s1e2, consumed: true, consumed_at: Date.current)
        LibraryItem.create!(user: user, item: s1e3, consumed: true, consumed_at: Date.current)
        LibraryItem.create!(user: user, item: s2e1, consumed: true, consumed_at: Date.current)

        expect(described_class.items_for(user)).to be_empty
      end
    end

    context 'when comic issues are consumed' do
      before do
        LibraryItem.create!(user: user, item: issue1, consumed: true, consumed_at: Date.current)
      end

      it 'returns the comic as in-progress with the next issue' do
        items = described_class.items_for(user)
        expect(items.size).to eq(1)

        item = items.first
        expect(item.series).to eq(comic)
        expect(item.media_type).to eq('Comic')
        expect(item.completed_count).to eq(1)
        expect(item.total_count).to eq(3)
        expect(item.percent).to eq(33)
        expect(item.next_item).to eq(issue2)
      end
    end

    context 'with privacy settings' do
      before do
        show_lib.update!(is_public: false)
        LibraryItem.create!(user: user, item: s1e1, consumed: true, consumed_at: Date.current)
      end

      it 'includes private items when public_only is false' do
        expect(described_class.items_for(user, public_only: false).size).to eq(1)
      end

      it 'excludes private items when public_only is true' do
        expect(described_class.items_for(user, public_only: true)).to be_empty
      end
    end
  end

  describe '.item_for' do
    it 'returns the in-progress item for a specific series' do
      LibraryItem.create!(user: user, item: s1e1, consumed: true, consumed_at: Date.current)
      item = described_class.item_for(user, tv_show)

      expect(item).to be_present
      expect(item.series).to eq(tv_show)
      expect(item.next_item).to eq(s1e2)
    end

    it 'returns nil when all episodes are watched' do
      [s1e1, s1e2, s1e3, s2e1].each do |ep|
        LibraryItem.create!(user: user, item: ep, consumed: true, consumed_at: Date.current)
      end

      expect(described_class.item_for(user, tv_show)).to be_nil
    end
  end
end
