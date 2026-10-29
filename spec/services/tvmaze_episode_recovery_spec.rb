# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TvmazeEpisodeRecovery do
  let(:show) { TvShow.create!(title: 'Recovery fixture') }
  let(:rows) do
    3.times.map do |n|
      { id: 100 + n, season: 2026, number: n + 1, name: "Chapter #{n + 1}",
        airdate: '2026-10-01', image: { original: 'https://static.tvmaze.com/image.jpg' }, runtime: 30 }
    end
  end

  before do
    show.update_columns(api_id: '793')
    stub_request(:get, 'https://api.tvmaze.com/shows/793/seasons')
      .to_return(body: [{ id: 194_376, number: 2026 }].to_json)
    stub_request(:get, 'https://api.tvmaze.com/seasons/194376/episodes').to_return(body: rows.to_json)
  end

  def recovery(**options)
    described_class.new(show, expected_api_id: '793', season: 2026, **options)
  end

  it 'previews by default without records, jobs or cover work, then requires the reviewed digest' do
    preview = recovery(batch_size: 2).call
    expect(preview).to include(dry_run: true, would_create: 2, created: 0, next_after_number: 2)
    expect(show.tv_episodes.count).to eq(0)
    expect { recovery(batch_size: 2).call(dry_run: false) }.to raise_error(ArgumentError, /digest/)
    expect do
      recovery(batch_size: 2).call(dry_run: false, expected_digest: 'wrong')
    end.to raise_error(ArgumentError, /digest/)
    expect do
      result = recovery(batch_size: 2).call(dry_run: false, expected_digest: preview[:digest])
      expect(result).to include(created: 2, next_after_number: 2)
    end.not_to have_enqueued_job
    expect(CoverImport.where(item_type: 'TvEpisode')).to be_empty
    expect(show.tv_episodes.pluck(:thumbnail_url)).to eq([nil, nil])
    expect(show.tv_episodes.order(:episode).pluck(:provider_id)).to eq(%w[100 101])
  end

  it 'creates only missing rows and never propagates whole-show completion or changes private history' do
    user = User.create!(name: 'Recovery viewer', password: 'password123')
    pilot = show.tv_episodes.create!(season: 2026, episode: 1, name: 'My custom pilot', summary: 'My custom summary')
    library = user.library_items.create!(item: show, consumed: true, rating: '4.5', review: 'Private review',
                                         is_public: false)
    watched = user.library_items.find_by!(item: pilot)
    snapshot = [LibraryItem.all.map(&:attributes), ConsumptionPass.all.map(&:attributes),
                ConsumptionPassEntry.all.map(&:attributes), Activity.all.map(&:attributes)]
    preview = recovery.call
    expect(preview).to include(would_create: 2, skipped_existing: 1)
    expect do
      recovery.call(dry_run: false, expected_digest: preview[:digest])
      recovery.call(dry_run: false, expected_digest: preview[:digest])
    end.not_to have_enqueued_job
    expect([LibraryItem.all.map(&:attributes), ConsumptionPass.all.map(&:attributes),
            ConsumptionPassEntry.all.map(&:attributes), Activity.all.map(&:attributes)]).to eq(snapshot)
    expect(pilot.reload).to have_attributes(name: 'My custom pilot', summary: 'My custom summary')
    expect(library.reload).to have_attributes(consumed: true, rating: '4.5', review: 'Private review', is_public: false)
    expect(watched.reload).to be_consumed
    expect(show.tv_episodes.count).to eq(3)
  end

  it 'caps writes at 250 rows and keeps specials and other seasons outside the batch' do
    large = 300.times.map { |n| rows.first.merge(id: 1000 + n, number: n + 1) }
    large += [rows.first.merge(number: 301, type: 'significant_special'), rows.first.merge(season: 2025)]
    stub_request(:get, 'https://api.tvmaze.com/seasons/194376/episodes').to_return(body: large.to_json)
    preview = recovery.call
    expect(preview).to include(batch_size: 250, would_create: 250, next_after_number: 250)
    expect { recovery.call(dry_run: false, expected_digest: preview[:digest]) }.not_to have_enqueued_job
    expect(show.tv_episodes.count).to eq(250)
    expect(recovery(after_number: 250).call).to include(batch_size: 50, next_after_number: nil)
  end

  it 'enforces identity, source activation, cursor and batch bounds before any write' do
    expect { described_class.new(show, expected_api_id: 'other', season: 2026) }.to raise_error(ArgumentError)
    expect { recovery(batch_size: 251) }.to raise_error(ArgumentError)
    expect { recovery(after_number: -1) }.to raise_error(ArgumentError)
    show.update_columns(api_id: '999')
    expect { recovery.call }.to raise_error(ArgumentError, /source/)
    show.update_columns(api_id: '793')
    allow(MediaSources::Registry).to receive(:enabled?).with('tvmaze', 'TvShow').and_return(false)
    expect { recovery.call }.to raise_error(MetadataProvider::Unavailable)
    expect(show.tv_episodes.count).to eq(0)
  end

  it 'advances an explicit cursor and rejects source changes, failures' do
    preview = recovery(after_number: 2).call
    expect(preview).to include(batch_size: 1, next_after_number: nil)
    changed = rows.map { |row| row.merge(name: 'Changed provider title') }
    stub_request(:get, 'https://api.tvmaze.com/seasons/194376/episodes').to_return(body: changed.to_json)
    expect { recovery(after_number: 2).call(dry_run: false, expected_digest: preview[:digest]) }
      .to raise_error(ArgumentError, /changed/)
    stub_request(:get, 'https://api.tvmaze.com/seasons/194376/episodes').to_return(status: 429)
    expect { recovery.call }.to raise_error(MediaSources::Http::Error, 'HTTP 429')
    expect(show.tv_episodes.count).to eq(0)
  end
end
