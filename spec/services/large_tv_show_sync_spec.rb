# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Large TV show sync and refresh' do
  let(:show) { TvShow.create!(title: 'Calendar-year soap') }
  let(:user) { User.create!(name: 'Soap viewer', password: 'password123') }
  let(:rows) do
    [{ id: 116_520, season: 1985, number: 1, name: 'Provider pilot', airdate: '1985-02-19' },
     { id: 116_521, season: 1985, number: 2, name: 'Second episode' },
     { id: 3_790_248, season: 2026, number: 173, name: 'Current episode' }]
  end

  before do
    show.update_columns(api_id: '793')
    details = { network: { name: 'BBC One' }, premiered: '1985-02-19',
                _embedded: { crew: [{ type: 'Writer', person: { id: 9, name: 'Writer' } }] } }
    stub_request(:get, %r{\Ahttps://api.tvmaze.com/shows/793(?:\?|$)}).to_return(body: details.to_json)
    stub_request(:get, 'https://api.tvmaze.com/shows/793/episodes?specials=1')
      .to_return(body: [{ summary: 'x' * MediaSources::Http::MAX_JSON_BYTES }].to_json)
    seasons = [{ id: 100, number: 1985, endDate: '1985-12-31' }, { id: 200, number: 2026, endDate: nil }]
    stub_request(:get, 'https://api.tvmaze.com/shows/793/seasons').to_return(body: seasons.to_json)
    stub_request(:get, 'https://api.tvmaze.com/seasons/100/episodes').to_return(body: rows.first(2).to_json)
    stub_request(:get, 'https://api.tvmaze.com/seasons/200/episodes').to_return(body: rows.last(1).to_json)
  end

  it 'uses the same seasonal fallback for initial sync and keeps source season and episode numbers' do
    show.send(:sync_episodes_from_api)
    expect(show.tv_episodes.order(:season, :episode).pluck(:season, :episode))
      .to eq([[1985, 1], [1985, 2], [2026, 173]])
    expect(show.tv_episodes.order(:season, :episode).pluck(:provider_id)).to eq(%w[116520 116521 3790248])
    expect(show.reload.api_id).to eq('793')
  end

  it 'refreshes in place, is idempotent and preserves library history, progress, private reviews and comments' do
    pilot = show.tv_episodes.create!(season: 1985, episode: 1, name: 'My pilot title', watched: true, review: 'Legacy note')
    custom = show.tv_episodes.create!(season: 0, episode: 99, name: 'My custom entry')
    library = user.library_items.create!(item: show, is_collected: true, is_public: false, review: 'Private series review')
    watched = user.library_items.create!(item: pilot, consumed: true, rating: '4.5', review: 'Private episode review',
                                         is_public: false)
    comment = Comment.create!(user: user, commentable: pilot, content: 'Keep this comment')
    pass = library.consumption_passes.sole
    entry_ids = pass.entries.pluck(:id)
    expect(MetadataRefresher.new(show, user).call).to eq('success')
    MetadataRefresh.update_all(requested_at: 10.minutes.ago)
    user.update!(metadata_requested_at: 1.minute.ago)
    expect(MetadataRefresher.new(show, user).call).to eq('unchanged')
    expect(show.tv_episodes.count).to eq(4)
    expect(pilot.reload).to have_attributes(name: 'My pilot title', watched: true, review: 'Legacy note')
    expect(watched.reload).to have_attributes(consumed: true, rating: '4.5', review: 'Private episode review',
                                              is_public: false)
    expect(library.reload).to have_attributes(is_public: false, review: 'Private series review')
    expect(pass.reload.entries.pluck(:id)).to eq(entry_ids)
    expect(comment.reload.commentable_id).to eq(pilot.id)
    expect(custom.reload.name).to eq('My custom entry')
  end

  it 'reports partial refresh without deleting old episodes when one season fails' do
    old = show.tv_episodes.create!(season: 1985, episode: 1, name: 'Existing pilot')
    stub_request(:get, 'https://api.tvmaze.com/seasons/100/episodes').to_return(status: 503)
    expect(MetadataRefresher.new(show, user).call).to eq('partial')
    expect(show.tv_episodes.exists?(old.id)).to be true
    expect(show.tv_episodes.where(season: 2026, episode: 173)).to exist
    expect(MetadataRefresh.find_by!(item: show).state).to eq('partial')
  end
end
