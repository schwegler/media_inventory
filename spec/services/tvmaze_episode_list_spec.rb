# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TvmazeEpisodeList do
  let(:full_url) { 'https://api.tvmaze.com/shows/793/episodes?specials=1' }
  let(:seasons_url) { 'https://api.tvmaze.com/shows/793/seasons' }

  def episode(id, year)
    { 'id' => id, 'name' => "Episode #{id}", 'season' => year, 'number' => 1, 'type' => 'regular' }
  end

  def oversized_list
    # Exercise the real byte guard rather than stubbing away the transport.
    stub_request(:get, full_url).to_return(body: [{ summary: 'x' * MediaSources::Http::MAX_JSON_BYTES }].to_json)
  end

  def season_list(count = 3)
    seasons = count.times.map { |n| { id: 10_000 + n, number: 1985 + n, endDate: '2000-12-31' } }
    stub_request(:get, seasons_url).to_return(body: seasons.to_json)
    seasons.each do |s|
      stub_request(:get, "https://api.tvmaze.com/seasons/#{s[:id]}/episodes")
        .to_return(body: [episode(s[:id], s[:number])].to_json)
    end
    seasons
  end

  it 'keeps the normal single-request path for small shows' do
    stub_request(:get, full_url).to_return(body: [episode(1, 2026)].to_json)
    list = described_class.new('793')
    expect(list.call).to eq([episode(1, 2026)])
    expect(list.partial).to be false
    expect(WebMock).not_to have_requested(:get, seasons_url)
  end

  it 'splits an oversized list across all 42 seasons without renumbering calendar-year seasons' do
    oversized_list
    seasons = season_list(42)
    list = described_class.new('793')
    rows = list.call
    expect(rows.size).to eq(42)
    expect(rows.map { |row| row['season'] }).to eq((1985..2026).to_a.reverse)
    expect(list.partial).to be false
    seasons.each do |s|
      expect(WebMock).to have_requested(:get, "https://api.tvmaze.com/seasons/#{s[:id]}/episodes").once
    end
    expect(MediaSources::Http::MAX_JSON_BYTES).to eq(2.megabytes)
  end

  it 'does not mistake server errors or rate limits for an oversized response' do
    [503, 429].each do |code|
      stub_request(:get, full_url).to_return(status: code)
      expect { described_class.new('793').call }.to raise_error(MediaSources::Http::Error, "HTTP #{code}")
    end
    expect(WebMock).not_to have_requested(:get, seasons_url)
  end

  it 'retains successful seasons and specials on failure and retries using ended-season caches' do
    oversized_list
    season_list
    latest = 'https://api.tvmaze.com/seasons/10002/episodes'
    middle = 'https://api.tvmaze.com/seasons/10001/episodes'
    special = episode(99, 1987).merge('number' => nil, 'type' => 'significant_special')
    stub_request(:get, latest).to_return(body: [episode(3, 1987), special].to_json)
    stub_request(:get, middle).to_return(status: 429)
    first = described_class.new('793', revalidate: true)
    expect(first.call.map { |row| row['id'] }).to eq([3, 99])
    expect(first.partial).to be true
    expect(WebMock).not_to have_requested(:get, 'https://api.tvmaze.com/seasons/10000/episodes')
    stub_request(:get, middle).to_return(body: [episode(2, 1986)].to_json)
    second = described_class.new('793', revalidate: true)
    expect(second.call.map { |row| row['season'] }).to eq([1987, 1987, 1986, 1985])
    expect(second.partial).to be false
    third = described_class.new('793', revalidate: true)
    expect(third.call.size).to eq(4)
    expect(WebMock).to have_requested(:get, middle).twice # one error, one success; then cached
  end

  it 'bounds aggregate seasons and rows and reports truncation as partial' do
    oversized_list
    season_list(4)
    stub_const('TvmazeEpisodeList::MAX_SEASONS', 2)
    list = described_class.new('793')
    expect(list.call.size).to eq(2)
    expect(list.partial).to be true
    stub_const('TvmazeEpisodeList::MAX_EPISODES', 1)
    list = described_class.new('793')
    expect(list.call.size).to eq(1)
    expect(list.partial).to be true
  end

  it 'stops at the caller deadline and preserves already fetched rows' do
    oversized_list
    season_list
    clock = 100.0
    allow(Process).to receive(:clock_gettime).and_call_original
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { clock }
    stub_request(:get, 'https://api.tvmaze.com/seasons/10001/episodes').to_return do
      clock = 110.0
      { body: [episode(3, 1987)].to_json }
    end
    list = described_class.new('793', deadline: 105.0)
    expect(list.call.map { |row| row['season'] }).to eq([1987])
    expect(list.partial).to be true
    expect(WebMock).not_to have_requested(:get, 'https://api.tvmaze.com/seasons/10000/episodes')
  end
end
