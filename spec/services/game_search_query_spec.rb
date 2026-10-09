# frozen_string_literal: true

require 'rails_helper'
RSpec.describe GameSearchQuery do
  it 'ranks an exact base game before DLC, soundtrack and related titles' do
    results = [
      { title: 'Vampire Survivors Soundtrack', api_id: 'steam_2', game_type: 'soundtrack' },
      { title: 'Vampire Survivors: Legacy', api_id: 'steam_3', game_type: 'dlc' },
      { title: 'Vampire Survivors', api_id: 'steam_1', game_type: 'game' }
    ]
    expect(described_class.new('Vampire Survivors').rank(results).first[:api_id]).to eq('steam_1')
  end
  it 'keeps same-title games from different providers rather than merging by title' do
    results = [{ title: 'Prey', api_id: 'steam_1', release_year: 2006 },
               { title: 'Prey', api_id: 'rawg_1', release_year: 2006 }]
    expect(described_class.new('Prey').rank(results).size).to eq(2)
  end
  it 'deduplicates strong provider IDs and prefers local records' do
    results = [{ title: 'Portal 2', api_id: 'steam_620', is_local: true },
               { title: 'Portal 2', api_id: 'steam_620' }]
    expect(described_class.new('Portal 2').rank(results)).to contain_exactly(include(is_local: true))
  end
  it 'keeps distinct manual catalog entries even when title and release year agree' do
    results = [{ title: 'Same title', release_year: 2006, catalog_id: 1, is_local: true },
               { title: 'Same title', release_year: 2006, catalog_id: 2, is_local: true }]
    expect(described_class.new('Same title').rank(results).map { |row| row[:catalog_id] }).to eq([1, 2])
  end
end
