# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Season zero watch-through boundaries' do
  let(:user) { User.create!(name: 'Viewer', password: 'password') }
  let(:show) { TvShow.create!(title: 'A show with extras') }
  let!(:extra) { show.tv_episodes.create!(season: 0, episode: 1, name: 'Behind the scenes') }
  let!(:other_extra) { show.tv_episodes.create!(season: 0, episode: 2, name: 'Trailer') }
  let!(:pilot) { show.tv_episodes.create!(season: 1, episode: 1, name: 'Pilot') }
  let!(:finale) { show.tv_episodes.create!(season: 1, episode: 2, name: 'Finale') }
  let!(:library) { LibraryItem.create!(user: user, item: show) }

  def watch(episode)
    child = user.library_items.find_or_initialize_by(item: episode)
    ConsumptionPasses.apply(user, episode, child, consumed: true, consumed_at: Date.current)
    child
  end

  it 'starts normal next-episode selection at season one while extras remain browsable' do
    pass = ConsumptionPasses.start(library)
    selection = NextSeriesEntry.new(show, pass)
    expect(selection.children.pluck(:id)).to contain_exactly(pilot.id, finale.id)
    expect(selection.next_item).to eq(pilot)
    expect(SeriesNeighbors.call(pilot)[:previous]).to be_nil
    expect(SeriesNeighbors.call(extra)).to eq(previous: nil, next: other_extra)
    expect(SeriesNeighbors.call(other_extra)[:next]).to be_nil
  end

  it 'ignores existing extra pass entries in totals, progress, continuation and activity without changing history' do
    watch(pilot)
    pass = library.consumption_passes.sole
    pass.entries.find_by!(item: pilot).update!(consumed_at: 1.day.ago)
    extra_library = user.library_items.create!(item: extra, consumed: true, review: 'Keep my review')
    legacy_entry = pass.entries.create!(item: extra, consumed_at: Time.current)
    history = [extra_library.attributes, legacy_entry.attributes]
    aggregate = InProgressTracker.items_for(user).sole
    single = InProgressTracker.item_for(user, show)
    [aggregate, single].each do |item|
      expect(item.total_count).to eq(2)
      expect(item.completed_count).to eq(1)
      expect(item.percent).to eq(50)
      expect(item.next_item).to eq(finale)
      expect(item.last_consumed_at.to_date).to eq(1.day.ago.to_date)
    end
    collection = SeriesCollection.new(show, user: user, library: library, params: { season: '0' })
    expect([collection.total, collection.completed, collection.season_total, collection.season_completed])
      .to eq([2, 1, 2, 1])
    expect([extra_library.reload.attributes, legacy_entry.reload.attributes]).to eq(history)
  end

  it 'does not let legacy extras prematurely complete a pass or prevent normal completion' do
    watch(pilot)
    pass = library.consumption_passes.sole
    pass.entries.create!(item: extra, consumed_at: Time.current)
    ConsumptionPasses.record(user, pilot)
    expect(pass.reload).to be_active
    watch(finale)
    expect(pass.reload).to be_completed
    expect(InProgressTracker.items_for(user)).to be_empty
    expect(pass.entries.find_by(item: extra)).to be_present
  end

  it 'allows explicit extras tracking without starting or reopening a watch-through' do
    child = watch(extra)
    expect(child.reload).to be_consumed
    expect(library.consumption_passes).to be_empty
    watch(pilot)
    watch(finale)
    pass = library.consumption_passes.sole
    expect(pass).to be_completed
    watch(other_extra)
    expect(pass.reload).to be_completed
    expect(pass.entries.where(item: [extra, other_extra])).to be_empty
  end

  it 'keeps extras lifetime status independent of a rewatch and supports explicit undo' do
    child = watch(extra)
    watch(pilot)
    watch(finale)
    rewatch = ConsumptionPasses.start(library)
    expect(rewatch).to be_rewatch
    expect(ConsumptionPasses.consumed?(extra, user: user)).to be true
    collection = SeriesCollection.new(show, user: user, library: library, params: { season: '0' })
    expect(collection.season_completed).to eq(1)
    expect(collection.completed).to eq(0)
    ConsumptionPasses.apply(user, extra, child, consumed: false, consumed_at: nil)
    expect(child.reload).not_to be_consumed
    expect(rewatch.reload.entries).to be_empty
    expect(InProgressTracker.item_for(user, show).next_item).to eq(pilot)
  end

  it 'marks only normal episodes when the full series is explicitly marked watched' do
    child = watch(extra)
    before = child.attributes
    library.update!(consumed: true)
    expect(user.library_items.find_by!(item: pilot)).to be_consumed
    expect(user.library_items.find_by!(item: finale)).to be_consumed
    expect(user.library_items.find_by(item: other_extra)).to be_nil
    expect(child.reload.attributes).to eq(before)
  end

  it 'does not put an extras-only series in progress or invent a next episode' do
    show.tv_episodes.watch_through.destroy_all
    pass = ConsumptionPasses.start(library)
    expect(NextSeriesEntry.new(show, pass).next_item).to be_nil
    expect(InProgressTracker.items_for(user)).to be_empty
    expect(InProgressTracker.item_for(user, show)).to be_nil
    collection = SeriesCollection.new(show, user: user, library: library)
    expect(collection.season).to eq(0)
    expect(collection.records.pluck(:id)).to contain_exactly(extra.id, other_extra.id)
  end
end
