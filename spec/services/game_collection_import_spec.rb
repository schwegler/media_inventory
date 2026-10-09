# frozen_string_literal: true

require 'rails_helper'
RSpec.describe GameCollectionImport do
  let(:user) { User.create!(name: 'Player', email: 'player@example.com', password: 'password123') }
  let(:game) { VideoGame.create!(title: 'Portal') }
  let(:data) do
    copy = { 'platform' => 'PC', 'access_method' => 'digital', 'ownership_status' => 'owned' }
    session = { 'started_at' => '2026-01-01T12:00:00Z', 'ended_at' => '2026-01-01T13:00:00Z', 'notes' => 'First hour' }
    { 'version' => 1, 'game' => { 'id' => game.id }, 'copies' => [copy],
      'playthroughs' => [{ 'platform' => 'PC', 'status' => 'currently_playing', 'progress' => 12,
                           'sessions' => [session] }],
      'journal' => [{ 'body' => 'Private notes', 'spoiler' => true }] }
  end
  it 'previews without writing and applies idempotently without overwriting reviews' do
    library = LibraryItem.create!(user: user, item: game, review: 'Keep me')
    preview = described_class.preview(data.to_json)
    expect(GameCopy.count).to eq(0)
    2.times { described_class.apply(user, preview) }
    expect(library.reload.review).to eq('Keep me')
    expect(library.game_copies.count).to eq(1)
    expect(library.game_playthroughs.count).to eq(1)
    expect(GameSession.count).to eq(1)
    expect(library.game_journal_entries.count).to eq(1)
  end
  it 'validates gameplay timestamps before applying data' do
    data['playthroughs'].first['sessions'].first['ended_at'] = '2025-01-01T12:00:00Z'
    expect { described_class.preview(data.to_json) }.to raise_error(described_class::Invalid)
    expect(GameCopy.count).to eq(0)
  end
  it 'imports CSV copies without matching a game by title' do
    csv = "game_id,platform,access_method,ownership_status\n#{game.id},Nintendo Switch,physical,owned\n"
    preview = described_class.preview(csv, format: 'csv')
    expect(described_class.apply(user, preview).game_copies.last.platform).to eq('Nintendo Switch')
  end
  it 'rejects ambiguous or missing canonical identity and oversized uploads' do
    expect do
      described_class.preview({ 'version' => 1,
                                'game' => { 'title' => 'Portal' } }.to_json)
    end.to raise_error(described_class::Invalid)
    expect { described_class.preview('x' * (described_class::MAX_BYTES + 1)) }.to raise_error(described_class::Invalid)
  end
end
