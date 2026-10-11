# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConsumptionPasses do
  let!(:user) do
    User.create!(name: 'Pass User', email: 'passes@example.com', password: 'password123',
                 password_confirmation: 'password123', confirmed_at: Time.current)
  end
  let!(:show) { TvShow.create!(title: 'Parks and Recreation') }
  let!(:show_lib) { LibraryItem.create!(user: user, item: show) }
  let!(:ep1) { show.tv_episodes.create!(name: 'Pilot', season: 1, episode: 1) }
  let!(:ep2) { show.tv_episodes.create!(name: 'Canvassing', season: 1, episode: 2) }

  def watch(episode, **attrs)
    lib = LibraryItem.find_or_initialize_by(user: user, item: episode)
    described_class.apply(user, episode, lib, ActionController::Parameters.new(consumed: true, **attrs).permit!)
  end

  def unwatch(episode)
    lib = LibraryItem.find_by!(user: user, item: episode)
    described_class.apply(user, episode, lib, ActionController::Parameters.new(consumed: false).permit!)
  end

  it 'creates a first pass the first time something is watched' do
    watch(ep1)
    pass = show_lib.consumption_passes.sole
    expect(pass).to be_active
    expect(pass.number).to eq(1)
    expect(pass.entries.pluck(:item_id)).to eq([ep1.id])
  end

  it 'records via LibraryItem writes that bypass the controller' do
    LibraryItem.create!(user: user, item: ep1, consumed: true, consumed_at: Date.current)
    expect(show_lib.consumption_passes.sole.entries.count).to eq(1)
  end

  it 'marks the pass completed when everything is watched' do
    watch(ep1)
    watch(ep2)
    pass = show_lib.consumption_passes.sole
    expect(pass).to be_completed
    expect(pass.completed_on).to eq(Date.current)
  end

  it 'removes the entry on undo in the first pass and reopens a completed pass' do
    watch(ep1)
    watch(ep2)
    unwatch(ep2)
    pass = show_lib.consumption_passes.sole
    expect(pass).to be_active
    expect(pass.entries.pluck(:item_id)).to eq([ep1.id])
    expect(LibraryItem.find_by(user: user, item: ep2)).not_to be_consumed
  end

  describe 're-watching' do
    before do
      watch(ep1)
      watch(ep2)
    end

    it 'starts a new active pass with no entries' do
      pass = described_class.start(show_lib)
      expect(pass.number).to eq(2)
      expect(pass).to be_active
      expect(pass.entries).to be_empty
    end

    it 'does not create a second active pass' do
      first = described_class.start(show_lib)
      expect(described_class.start(show_lib)).to eq(first)
    end

    it 'records a watch in the new pass even though the episode was already watched' do
      described_class.start(show_lib)
      watch(ep1)
      expect(show_lib.consumption_passes.find_by(number: 2).entries.pluck(:item_id)).to eq([ep1.id])
      expect(show_lib.consumption_passes.find_by(number: 1).entries.count).to eq(2)
    end

    it 'keeps the lifetime watched flag when undoing during a re-watch' do
      described_class.start(show_lib)
      watch(ep1)
      unwatch(ep1)
      expect(LibraryItem.find_by(user: user, item: ep1)).to be_consumed
      expect(show_lib.consumption_passes.find_by(number: 2).entries).to be_empty
    end

    it 'does not reopen a completed pass when an already-covered episode is touched without a new pass' do
      described_class.record(user, ep1)
      expect(show_lib.consumption_passes.sole).to be_completed
    end
  end

  describe 'dismiss and resume' do
    before { watch(ep1) }

    it 'dismisses without losing progress and resumes later' do
      pass = show_lib.consumption_passes.sole
      described_class.dismiss(pass)
      expect(pass.reload).to be_dismissed
      expect(pass.entries.count).to eq(1)

      described_class.resume(show_lib)
      expect(pass.reload).to be_active
    end

    it 'reactivates a dismissed pass when more is watched' do
      described_class.dismiss(show_lib.consumption_passes.sole)
      watch(ep2)
      expect(show_lib.consumption_passes.count).to eq(1)
    end
  end

  it 'forgets entries when the episode library item is removed' do
    watch(ep1)
    LibraryItem.find_by!(user: user, item: ep1).destroy
    expect(show_lib.consumption_passes.sole.entries).to be_empty
  end

  describe '.consumed?' do
    it 'reports true when watched in first pass' do
      watch(ep1)
      expect(described_class.consumed?(ep1, user: user)).to be true
      expect(described_class.consumed?(ep2, user: user)).to be false
    end

    it 'reports false during a re-watch until watched in that pass' do
      watch(ep1)
      watch(ep2)
      described_class.start(show_lib)

      expect(described_class.consumed?(ep1, user: user)).to be false
      expect(described_class.consumed?(ep2, user: user)).to be false

      watch(ep1)
      expect(described_class.consumed?(ep1, user: user)).to be true
      expect(described_class.consumed?(ep2, user: user)).to be false
    end
  end

  describe '.current_pass' do
    it 'returns the active pass' do
      watch(ep1)
      expect(described_class.current_pass(show_lib)&.number).to eq(1)
    end

    it 'returns the dismissed pass if dismissed' do
      watch(ep1)
      pass = show_lib.consumption_passes.sole
      described_class.dismiss(pass)
      expect(described_class.current_pass(show_lib)).to eq(pass)
    end

    it 'returns nil when pass is completed and no active pass' do
      watch(ep1)
      watch(ep2)
      expect(described_class.current_pass(show_lib)).to be_nil
    end
  end
end
