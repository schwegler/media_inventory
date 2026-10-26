# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlbumTrackAudit do
  let(:album) { Album.create!(title: 'Audit only') }
  let(:rows) do
    [{ 'provider_id' => 'itunes:101', 'title' => 'Song 1', 'disc_number' => 1, 'track_number' => 1 },
     { 'provider_id' => 'itunes:102', 'title' => 'Song 2', 'disc_number' => 1, 'track_number' => 2 }]
  end
  let(:adapter) { instance_double(MetadataProvider, provider: 'iTunes', partial: false, album_release_id: nil) }
  let(:audit) { described_class.new(ids: [album.id]) }

  before do
    album.update_columns(api_id: 'itunes_42')
    allow(MetadataProvider).to receive(:new).and_return(adapter)
    allow(adapter).to receive(:call).and_return([{ metadata_details: {} }, rows])
  end

  it 'requires explicit IDs and refuses an empty target scope' do
    expect { described_class.new(ids: []) }.to raise_error(ArgumentError, /Explicit/)
    expect { described_class.new(ids: ['all']) }.to raise_error(ArgumentError)
    expect { described_class.new(ids: [1], limit: 0) }.to raise_error(ArgumentError)
    expect { described_class.new(ids: [1], limit: 51) }.to raise_error(ArgumentError)
  end

  it 'reports missing, partial and complete lists without changing tracks or creating a refresh record' do
    expect(audit.report(album)).to include(classification: 'missing', eligible_for_review: true)
    expect(album.album_tracks).to be_empty
    expect(album.metadata_refresh).to be_nil
    AlbumMetadata.reconcile(album, rows.take(1))
    expect(audit.report(album)).to include(classification: 'partial', proposed_additions: [rows.last])
    AlbumMetadata.reconcile(album, rows)
    before = album.album_tracks.order(:id).map(&:attributes)
    expect(audit.report(album)).to include(classification: 'already_complete', proposed_additions: [])
    expect(album.album_tracks.order(:id).map(&:attributes)).to eq(before)
  end

  it 'separates edited or unverified data and mismatched editions without suggesting identity changes' do
    AlbumMetadata.reconcile(album, rows)
    album.album_tracks.first.update!(title: 'Personal title')
    expect(audit.report(album)).to include(classification: 'user_modified_or_unverified', eligible_for_review: false)
    changed = rows.map { |row| row.merge('provider_id' => "other:#{row['provider_id']}") }
    allow(adapter).to receive(:call).and_return([{ metadata_details: {} }, changed])
    expect(audit.report(album)).to include(classification: 'wrong_edition', eligible_for_review: false)
    expect(album.reload.api_id).to eq('itunes_42')
  end

  it 'flags a single identity even if its two-track list is complete' do
    allow(adapter).to receive(:call).and_return([{ metadata_details: { 'primary-type' => 'Single' } }, rows])
    expect(audit.report(album)).to include(classification: 'wrong_edition', eligible_for_review: false)
  end

  it 'does not approve a partial provider response for repair' do
    allow(adapter).to receive(:partial).and_return(true)
    expect(audit.report(album)).to include(classification: 'missing', source_state: 'partial', eligible_for_review: false)
  end

  it 'emits a stable checkpoint, limits explicit IDs and stops for retry on provider failure' do
    output = StringIO.new
    service = described_class.new(ids: [album.id, album.id + 1], limit: 1, output: output)
    allow(service).to receive(:sleep)
    allow(adapter).to receive(:call).and_raise(MetadataProvider::RateLimited)
    service.run
    evidence = JSON.parse(output.string)
    expect(evidence).to include('album_id' => album.id, 'checkpoint_after_id' => 0,
                                'source_state' => 'rate_limited', 'dry_run' => true)
    expect(MetadataRefresh.count).to eq(0)
  end
  it 'produces repeatable evidence and advances only completed explicit targets' do
    first = audit.report(album)
    expect(audit.report(album)).to eq(first)
    output = StringIO.new
    service = described_class.new(ids: [album.id], limit: 1, output: output)
    allow(service).to receive(:sleep)
    service.run
    expect(JSON.parse(output.string)).to include('checkpoint_after_id' => album.id, 'classification' => 'missing')
    expect(album.album_tracks).to be_empty
    expect(album.metadata_refresh).to be_nil
  end
  it 'excludes extra existing identities that the source cannot verify from the repair scope' do
    AlbumMetadata.reconcile(album, rows)
    album.album_tracks.create!(provider_id: 'manual:extra', title: 'Manual extra', disc_number: 2, track_number: 1)
    result = audit.report(album)
    expect(result).to include(classification: 'user_modified_or_unverified', eligible_for_review: false,
                              proposed_additions: [])
    expect(album.album_tracks.count).to eq(3)
  end
end
