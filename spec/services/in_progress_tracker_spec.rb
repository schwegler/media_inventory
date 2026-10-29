# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InProgressTracker do
  include ActiveSupport::Testing::TimeHelpers

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

    context 'when watching episodes out of series order' do
      let!(:s3e1) { tv_show.tv_episodes.create!(name: 'Go Big or Go Home', season: 3, episode: 1) }
      let!(:s3e2) { tv_show.tv_episodes.create!(name: 'Flu Season', season: 3, episode: 2) }
      let!(:s3e3) { tv_show.tv_episodes.create!(name: 'Time Capsule', season: 3, episode: 3) }

      it 'continues in season three when earlier seasons are unwatched' do
        LibraryItem.create!(user: user, item: s3e1, consumed: true, consumed_at: Date.current)

        expect(described_class.items_for(user).sole.next_item).to eq(s3e2)
      end

      it 'continues after the most recently marked episode even when a later episode is already watched' do
        travel_to 1.day.ago do
          LibraryItem.create!(user: user, item: s3e3, consumed: true, consumed_at: Date.current)
        end
        LibraryItem.create!(user: user, item: s3e1, consumed: true, consumed_at: 1.week.ago.to_date)

        expect(described_class.items_for(user).sole.next_item).to eq(s3e2)
      end

      it 'uses the latest entry when episodes are marked at the same time' do
        travel_to Time.current do
          LibraryItem.create!(user: user, item: s3e3, consumed: true, consumed_at: Date.current)
          LibraryItem.create!(user: user, item: s3e1, consumed: true, consumed_at: Date.current)
        end

        expect(described_class.item_for(user, tv_show).next_item).to eq(s3e2)
      end

      it 'skips watched episodes after the most recently marked episode' do
        LibraryItem.create!(user: user, item: s3e2, consumed: true, consumed_at: Date.current)
        LibraryItem.create!(user: user, item: s3e1, consumed: true, consumed_at: Date.current)

        expect(described_class.items_for(user).sole.next_item).to eq(s3e3)
      end

      it 'wraps to the earliest unwatched episode and then continues from there' do
        LibraryItem.create!(user: user, item: s3e3, consumed: true, consumed_at: Date.current)

        expect(described_class.item_for(user, tv_show).next_item).to eq(s1e1)

        LibraryItem.create!(user: user, item: s1e1, consumed: true, consumed_at: Date.current)

        expect(described_class.item_for(user, tv_show).next_item).to eq(s1e2)
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

      it 'includes TV progress independently of private review visibility' do
        expect(described_class.items_for(user, public_only: true).map(&:series)).to eq([tv_show])
      end
    end
  end

  describe 'bounded candidates and release eligibility' do
    it 'prefers available releases over unknown and future dates, preserving manual history' do
      LibraryItem.create!(user: user, item: s1e1, consumed: true, consumed_at: Date.current)
      s1e2.update!(air_date: 1.week.from_now.to_date)
      s1e3.update!(air_date: nil)
      s2e1.update!(air_date: Date.current)
      expect(described_class.item_for(user, tv_show).next_item).to eq(s2e1)
      LibraryItem.create!(user: user, item: s2e1, consumed: true, consumed_at: Date.current)
      expect(described_class.item_for(user, tv_show).next_item).to eq(s1e3)
      LibraryItem.create!(user: user, item: s1e3, consumed: true, consumed_at: Date.current)
      expect(described_class.item_for(user, tv_show).next_item).to eq(s1e2)
    end

    it 'keeps unnumbered specials after numbered issues without changing identity' do
      special = comic.comic_issues.create!(title: '#27AU', issue_number: nil)
      LibraryItem.create!(user: user, item: issue1, consumed: true, consumed_at: Date.current)
      expect(described_class.item_for(user, comic).next_item).to eq(issue2)
      expect(SeriesNeighbors.call(issue1)[:next]).to eq(issue2)
      expect(SeriesNeighbors.call(special)[:previous]).to eq(issue3)
      expect(special.reload.title).to eq('#27AU')
    end

    it 'instantiates bounded episode candidates for a thousand-entry series' do
      tv_show.tv_episodes.insert_all!(1000.times.map do |index|
        { name: "Long episode #{index}", season: 3, episode: index + 1 }
      end)
      LibraryItem.create!(user: user, item: s1e1, consumed: true, consumed_at: Date.current)
      instantiated = 0
      subscriber = lambda do |*args|
        payload = args.last
        instantiated += payload[:record_count] if payload[:class_name] == 'TvEpisode'
      end
      item = ActiveSupport::Notifications.subscribed(subscriber, 'instantiation.active_record') do
        described_class.item_for(user, tv_show)
      end
      expect(item.total_count).to eq(1004)
      expect(item.next_item).to eq(s1e2)
      expect(instantiated).to be <= 2
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

RSpec.describe 'Progress activity ordering' do
  include ActiveSupport::Testing::TimeHelpers

  let!(:user) { User.create!(name: 'Activity tester', password: 'password123') }

  def start_show(title)
    show = TvShow.create!(title: title)
    library = user.library_items.create!(item: show, is_public: true)
    2.times { |i| show.tv_episodes.create!(name: "Episode #{i}", season: 1, episode: i + 1) }
    ConsumptionPasses.start(library)
  end

  it 'uses immutable start time for untouched passes and stable library IDs for equal activity times' do
    travel_to(Time.current.change(usec: 0)) do
      first = start_show('First')
      second = start_show('Second')
      first.touch(time: 1.year.from_now)
      expect(InProgressTracker.items_for(user, limit: 2).map(&:pass)).to eq([second, first])
      expect(InProgressTracker.items_for(user).last.last_consumed_at).to eq(first.created_at)
    end
  end

  it 'applies the limit after skipping empty or already-complete active passes' do
    valid = start_show('Valid')
    empty = start_show('No children')
    empty.library_item.item.tv_episodes.destroy_all
    completed = start_show('Already complete')
    completed.library_item.item.tv_episodes.each do |episode|
      completed.entries.create!(item: episode, consumed_at: Time.current)
    end
    expect(InProgressTracker.items_for(user, limit: 2).map(&:pass)).to eq([valid])
  end

  it 'ranks private owner games by session end time across media, never edits, with one run per title' do
    pass = start_show('Active show')
    pass.entries.create!(item: pass.library_item.item.tv_episodes.first, consumed_at: 1.day.ago)
    game = VideoGame.create!(title: 'Active game')
    library = user.library_items.create!(item: game)
    run = library.game_playthroughs.create!(status: 'currently_playing')
    run.game_sessions.create!(started_at: 3.days.ago, ended_at: 3.days.ago + 1.hour)
    run.touch(time: 1.year.from_now)
    expect(InProgressTracker.items_for(user, include_games: true).map(&:media_type)).to eq(%w[TvShow VideoGame])
    run.game_sessions.create!(started_at: 1.hour.ago, ended_at: Time.current)
    expect(InProgressTracker.items_for(user, limit: 1, include_games: true).first.playthrough).to eq(run)
    expect(InProgressTracker.items_for(user, public_only: true, include_games: true).map(&:media_type)).to eq(['TvShow'])
    library.game_playthroughs.create!(status: 'completed')
    expect(InProgressTracker.items_for(user, include_games: true).map(&:media_type)).to eq(['TvShow'])
  end
  it 'builds next-entry candidates only for the visible slice, with accurate totals' do
    15.times { |index| start_show("Paged series #{index}") }
    tracker = InProgressTracker.new(user)
    expect(NextSeriesEntry).to receive(:new).exactly(2).times.and_call_original
    items = tracker.items(limit: 2, offset: 12, sort: 'title')
    expect(items.size).to eq(2)
    expect(tracker.total_count).to eq(15)
  end
end
