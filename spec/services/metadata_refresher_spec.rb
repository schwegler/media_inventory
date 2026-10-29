# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MetadataRefresher do
  let(:user) { User.create!(name: 'Reader', password: 'password') }
  let(:show) { TvShow.create!(title: 'My title') }
  let(:episode) do
    show.tv_episodes.create!(season: 1, episode: 1, name: 'Custom pilot', watched: true, review: 'Legacy note')
  end
  let(:rows) { [{ 'name' => 'Provider pilot', 'season' => 1, 'number' => 1, 'summary' => 'Updated summary' }] }

  before do
    show.update_columns(api_id: '42')
    stub_request(:get, 'https://api.tvmaze.com/shows/42').to_return(
      body: { network: { name: 'A network' }, image: { original: 'https://images.example/cover.jpg' } }.to_json
    )
    stub_request(:get, 'https://api.tvmaze.com/shows/42/episodes?specials=1').to_return(body: rows.to_json)
  end

  it 'releases the item lease and reports queue saturation without requesting providers' do
    allow(RefreshMediaMetadataJob).to receive(:perform_later).and_return(false)
    expect(described_class.new(show, user).enqueue).to eq('queue_busy')
    expect(MetadataRefresh.find_by!(item: show).requested_at).to be_nil
    expect(WebMock).not_to have_requested(:get, 'https://api.tvmaze.com/shows/42')
  end

  def expire_cooldown
    MetadataRefresh.update_all(requested_at: 10.minutes.ago)
    user.update!(metadata_requested_at: 1.minute.ago)
  end

  it 'reconciles idempotently and preserves child IDs, personal state, comments and library entries' do
    entry = LibraryItem.create!(user: user, item: episode, consumed: true, rating: '4.5', review: 'Loved this')
    comment = Comment.create!(user: user, commentable: episode, content: 'A comment')
    id = episode.id
    expect(described_class.call(show, user)).to eq('success')
    expire_cooldown
    expect(described_class.call(show, user)).to eq('unchanged')
    expect(show.tv_episodes.count).to eq(1)
    expect(episode.reload.id).to eq(id)
    expect(episode.name).to eq('Custom pilot')
    expect(episode.watched).to be true
    expect(episode.review).to eq('Legacy note')
    expect(episode.summary).to eq('Updated summary')
    expect(entry.reload.attributes.slice('consumed', 'rating', 'review')).to eq(
      'consumed' => true, 'rating' => '4.5', 'review' => 'Loved this'
    )
    expect(comment.reload.commentable).to eq(episode)
  end

  context 'with the combined Ghosts Halloween special' do
    let(:special) do
      { 'id' => 3_684_533, 'name' => 'Halloween 6: The Mirror – Parts One & Two',
        'season' => 6, 'number' => nil, 'type' => 'significant_special', 'airdate' => '2026-10-29' }
    end
    let(:rows) do
      [{ 'id' => 100, 'name' => 'Pilot', 'season' => 1, 'number' => 1 }, special,
       special.merge('id' => 3_684_534, 'name' => 'Christmas Special', 'airdate' => '2026-12-10')]
    end

    it 'keeps distinct unnumbered specials and refreshes them idempotently by provider ID' do
      expect(described_class.call(show, user)).to eq('success')
      imported = show.tv_episodes.find_by!(provider_id: '3684533')
      expect(imported.attributes.slice('season', 'episode', 'name', 'air_date')).to eq(
        'season' => 6, 'episode' => nil, 'name' => special['name'], 'air_date' => '2026-10-29'
      )
      expect(imported.metadata_details['Episode type']).to eq('significant_special')
      expire_cooldown
      expect(described_class.call(show, user)).to eq('unchanged')
      expect(show.tv_episodes.where(season: 6).pluck(:provider_id)).to contain_exactly('3684533', '3684534')
      expect(show.tv_episodes.find_by!(provider_id: '3684533').id).to eq(imported.id)
    end

    it 'preserves completed-series history without marking new specials watched' do
      episode
      library = LibraryItem.create!(user: user, item: show, consumed: true, consumed_at: Date.new(2026, 5, 21))
      original_library = library.reload.attributes
      original_entries = user.library_items.order(:id).map(&:attributes)
      original_passes = library.consumption_passes.order(:id).map(&:attributes)
      original_pass_entries = ConsumptionPassEntry.order(:id).map(&:attributes)
      expect(described_class.call(show, user)).to eq('success')
      expect(library.reload.attributes).to eq(original_library)
      expect(user.library_items.order(:id).map(&:attributes)).to eq(original_entries)
      expect(library.consumption_passes.order(:id).map(&:attributes)).to eq(original_passes)
      expect(ConsumptionPassEntry.order(:id).map(&:attributes)).to eq(original_pass_entries)
      expect(show.tv_episodes.where(season: 6).pluck(:watched)).to eq([false, false])
      expect(episode.reload.watched).to be true
    end
  end

  it 'keeps existing artwork on provider failure and reports rate limits' do
    show.update_columns(thumbnail_url: 'https://images.example/old.jpg')
    stub_request(:get, 'https://api.tvmaze.com/shows/42').to_return(status: 429)
    expect(described_class.call(show, user)).to eq('rate_limited')
    expect(show.reload.thumbnail_url).to eq('https://images.example/old.jpg')
  end

  it 'reports partial success when episodes are unavailable' do
    episode
    stub_request(:get, 'https://api.tvmaze.com/shows/42/episodes?specials=1').to_return(status: 503)
    expect(described_class.call(show, user)).to eq('partial')
    expect(show.tv_episodes.count).to eq(1)
    expect(show.reload.thumbnail_url).to eq('https://images.example/cover.jpg')
  end

  it 'protects an active claim and also rate limits requests across different items' do
    MetadataRefresh.create!(item: show, state: 'refreshing', requested_at: Time.current)
    expect(described_class.call(show, user)).to eq('cooldown')
    expect(WebMock).not_to have_requested(:get, 'https://api.tvmaze.com/shows/42')
    MetadataRefresh.delete_all
    described_class.call(show, user)
    other = TvShow.create!(title: 'Other')
    expect(described_class.call(other, user)).to eq('cooldown')
  end

  it 'rolls back invalid provider data without deleting old children' do
    episode
    stub_request(:get, 'https://api.tvmaze.com/shows/42').to_return(body: '{bad json')
    expect(described_class.call(show, user)).to eq('failed')
    expect(show.tv_episodes.count).to eq(1)
  end

  it 'never replaces uploaded artwork or a custom network' do
    show.update_columns(network: 'My network')
    show.cover_image.attach(io: StringIO.new('image'), filename: 'cover.jpg', content_type: 'image/jpeg')
    # Child imports are deferred, so this refresh creates the provider episode.
    expect(described_class.call(show, user)).to eq('success')
    expect(show.reload.thumbnail_url).to be_nil
    expect(show.network).to eq('My network')
    expect(show.cover_image).to be_attached
  end

  it 'reconciles comic issues in place without resetting read state' do
    comic = Comic.create!(title: 'My comic')
    comic.update_columns(api_id: '123')
    issue = comic.comic_issues.create!(issue_number: 1, title: 'My title', read: true, review: 'Note')
    entry = LibraryItem.create!(user: user, item: issue, consumed: true, rating: '5', review: 'Keep')
    ApiConfiguration.create!(source_name: 'ComicVine', is_active: true, access_token: 'test')
    stub_request(:get, 'https://comicvine.gamespot.com/api/volume/4050-123/')
      .with(query: { api_key: 'test', format: 'json' }).to_return(body: { status_code: 1, results: {} }.to_json)
    issue_payload = { status_code: 1, number_of_total_results: 1,
                      results: [{ id: 789, issue_number: '1', name: 'Provider title', deck: 'Details' }] }
    stub_request(:get, 'https://comicvine.gamespot.com/api/issues/')
      .with(query: hash_including('filter' => 'volume:123')).to_return(body: issue_payload.to_json)
    expect(described_class.call(comic, user)).to eq('success')
    expire_cooldown
    expect(described_class.call(comic, user)).to eq('unchanged')
    expect(comic.comic_issues.count).to eq(1)
    expect(issue.reload.read).to be true
    expect(issue.title).to eq('My title')
    expect(issue.review).to eq('Note')
    expect(entry.reload.review).to eq('Keep')
    expect(issue.provider_id).to eq('789')
  end
end
