# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RefreshChildMetadataJob do
  include ActiveJob::TestHelper

  it 'imports individual issue creators and details without touching personal data' do
    comic = Comic.create!(title: 'A comic')
    comic.update_columns(api_id: '42')
    ApiConfiguration.create!(source_name: 'ComicVine', media_type: 'Comic', is_active: true, access_token: 'test')
    issue = comic.comic_issues.create!(issue_number: 2, provider_id: '123', title: 'My title', read: true, review: 'Keep')
    row = { person_credits: [{ name: 'Issue artist', role: 'penciler, inker' },
                             { name: 'Issue writer', role: 'writer' }, { name: 'Editor', role: 'editor' }],
            character_credits: [{ name: 'Hero' }], story_arc_credits: [{ name: 'An arc' }],
            store_date: '2026-10-01', description: '<p>Issue summary</p>' }
    stub_request(:get, 'https://comicvine.gamespot.com/api/issue/4000-123/')
      .with(query: { api_key: 'test', format: 'json' })
      .to_return(body: { status_code: 1, results: row }.to_json)

    described_class.perform_now(issue)
    expect(issue.reload.credits).to include(a_hash_including('name' => 'Issue artist', 'role' => 'Penciler'),
                                            a_hash_including('name' => 'Issue artist', 'role' => 'Inker'))
    expect(issue.metadata_details).to include('Characters' => 'Hero', 'Story arcs' => 'An arc',
                                              'Store date' => '2026-10-01')
    expect(issue.summary).to eq('<p>Issue summary</p>')
    expect(issue.attributes).to include('read' => true, 'review' => 'Keep', 'title' => 'My title')
  end

  it 'imports TVMaze guest characters and episode crew, preserving existing details and watched state' do
    show = TvShow.create!(title: 'A show')
    show.update_columns(api_id: '42')
    episode = show.tv_episodes.create!(season: 1, episode: 2, provider_id: '123', watched: true,
                                       review: 'Keep', metadata_details: { 'Runtime' => '42 minutes' })
    stub_request(:get, 'https://api.tvmaze.com/episodes/123/guestcast')
      .to_return(body: [{ person: { name: 'Guest actor' }, character: { name: 'The doctor' } }].to_json)
    stub_request(:get, 'https://api.tvmaze.com/episodes/123/guestcrew')
      .to_return(body: [{ person: { name: 'Episode director' }, type: 'Director' },
                        { person: { name: 'Episode writer' }, type: 'Writer' }].to_json)
    described_class.perform_now(episode)
    expect(episode.reload.credits).to include(a_hash_including('name' => 'Guest actor', 'role' => 'Guest star',
                                                               'character' => 'The doctor'))
    expect(episode.credits).to include(a_hash_including('name' => 'Episode director', 'role' => 'Director'))
    expect(episode.metadata_details).to eq('Runtime' => '42 minutes')
    expect(episode.attributes).to include('watched' => true, 'review' => 'Keep')
  end

  it 'enqueues enrichment for existing children even when list metadata is unchanged' do
    show = TvShow.create!(title: 'A show')
    show.update_columns(api_id: '42')
    episode = show.tv_episodes.create!(season: 1, episode: 1, name: 'Pilot', provider_id: '123')
    row = { 'id' => 123, 'season' => 1, 'number' => 1, 'name' => 'Pilot' }
    expect do
      expect(MetadataChildren.episodes(show, [row])).to eq(0)
    end.to have_enqueued_job(described_class).with(episode, revalidate: false)
    comic = Comic.create!(title: 'A comic')
    issue = comic.comic_issues.create!(issue_number: 1, provider_id: '456', title: 'Issue')
    expect do
      expect(MetadataChildren.issues(comic, [{ 'id' => 456, 'issue_number' => '1', 'name' => 'Issue' }])).to eq(0)
    end.to have_enqueued_job(described_class).with(issue, revalidate: false)
  end

  it 'keeps existing credits when a provider has no credits or returns an error' do
    show = TvShow.create!(title: 'A show')
    show.update_columns(api_id: '42')
    credits = [{ 'name' => 'Saved guest', 'role' => 'Guest star' }]
    episode = show.tv_episodes.create!(season: 1, episode: 1, provider_id: '123', credits: credits)
    stub_request(:get, 'https://api.tvmaze.com/episodes/123/guestcast').to_return(body: '[]')
    stub_request(:get, 'https://api.tvmaze.com/episodes/123/guestcrew').to_return(body: '[]')
    described_class.perform_now(episode)
    expect(episode.reload.credits).to eq(credits)
    stub_request(:get, 'https://api.tvmaze.com/episodes/123/guestcrew').to_return(status: 429)
    expect { described_class.perform_now(episode, revalidate: true) }.to have_enqueued_job(described_class)
    expect(episode.reload.credits).to eq(credits)
  end

  it 'does not request TVMaze credits for TMDB IDs or disabled sources' do
    show = TvShow.create!(title: 'A show')
    show.update_columns(api_id: 'tmdb_42')
    episode = show.tv_episodes.create!(season: 1, episode: 1, provider_id: '123')
    described_class.perform_now(episode)
    show.update_columns(api_id: '42')
    ApiConfiguration.create!(source_name: 'tvmaze', media_type: 'TvShow', is_active: false)
    described_class.perform_now(episode)
    expect(WebMock).not_to have_requested(:get, /tvmaze/)
  end
end
