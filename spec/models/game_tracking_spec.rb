# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'Game tracking models' do
  let(:user) { User.create!(name: 'Player', email: 'player@example.com', password: 'password123') }
  let(:game) { VideoGame.create!(title: 'Portal') }
  let(:library) { LibraryItem.create!(user: user, item: game) }
  it 'allows multiple physical, digital and subscription copies without treating subscription access as ownership' do
    %w[physical digital subscription].each do |method|
      library.game_copies.create!(platform: 'PC', access_method: method)
    end
    expect(library.game_copies.count).to eq(3)
    expect(library.game_copies.where.not(access_method: 'subscription').count).to eq(2)
  end
  it 'records separate playthroughs and derives session duration without imported totals' do
    first = library.game_playthroughs.create!(status: 'beaten')
    second = library.game_playthroughs.create!(status: 'replaying')
    session = first.game_sessions.create!(started_at: Time.current - 90.minutes, ended_at: Time.current)
    expect(session.duration_minutes).to eq(90.0)
    expect(second.game_sessions).to be_empty
  end
  it 'rejects backwards sessions and invalid progress' do
    playthrough = library.game_playthroughs.create!
    expect(playthrough.game_sessions.new(started_at: Time.current, ended_at: 1.hour.ago)).not_to be_valid
    expect(library.game_playthroughs.new(progress: 101)).not_to be_valid
  end
  it 'removes only personal child records when a library record is deleted' do
    library.game_journal_entries.create!(body: 'Private quest notes')
    library.destroy!
    expect(GameJournalEntry.count).to eq(0)
    expect(VideoGame.exists?(game.id)).to be(true)
  end
end
