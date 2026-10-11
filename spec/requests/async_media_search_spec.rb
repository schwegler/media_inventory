# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Asynchronous media search', type: :request do
  include ActiveJob::TestHelper

  before { MediaSources::Registry::CACHE.clear }

  it 'returns promptly without external HTTP and serves results after the job finishes' do
    expect { get '/media/autocomplete', params: { q: 'Portal', type: 'video_game', async: '1' } }
      .to have_enqueued_job(MediaSearchJob)
    expect(response).to have_http_status(:accepted)
    expect(WebMock).not_to have_requested(:get, /store.steampowered.com/)
    perform_enqueued_jobs(only: MediaSearchJob)
    get '/media/autocomplete', params: { q: 'Portal', type: 'video_game', async: '1' }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to be_an(Array)
  end

  it 'returns local and completed provider matches while slower providers are pending' do
    TvShow.create!(title: 'Trivial Pursuit', release_year: 2024)
    allow(MediaSearchService).to receive(:request).and_return(
      state: 'pending', results: [{ title: 'Trivial Pursuit', release_year: 1993, source: 'tvmaze' }]
    )
    get '/media/autocomplete', params: { q: 'Trivial Pursuit', type: 'tv_show', async: '1' }
    expect(response).to have_http_status(:accepted)
    expect(JSON.parse(response.body)).to include(
      hash_including('title' => 'Trivial Pursuit', 'is_local' => true),
      hash_including('release_year' => 1993, 'source' => 'tvmaze')
    )
    expect(WebMock).not_to have_requested(:get, /api.tvmaze.com/)
  end

  it 'coalesces polling and tracks the latest query from a modal' do
    client = 'search-client-123456'
    2.times do
      get '/media/autocomplete', params: { q: 'Tri', type: 'tv_show', async: '1', search_client: client }
    end
    expect(enqueued_jobs.count { |job| job[:job] == MediaSearchJob }).to eq(1)
    get '/media/autocomplete', params: { q: 'Trivial', type: 'tv_show', async: '1', search_client: client }
    latest = MediaSources::Registry::CACHE.read(['search-client-v1', client])
    expect(latest).to eq(enqueued_jobs.last[:args][2])
  end
end
