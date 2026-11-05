# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaSearchJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  let(:cache) { MediaSources::Registry::CACHE }

  before { cache.clear }

  it 'publishes provider results before the complete search finishes' do
    partial = [{ title: 'Trivial Pursuit', source: 'tvmaze' }]
    allow(MediaSearchService).to receive(:call) do |_query, _type, &progress|
      progress.call(partial)
      expect(cache.read('search')).to eq(state: 'pending', results: partial)
      partial
    end

    described_class.perform_now('Trivial Pursuit', 'tv_show', 'search')
    expect(cache.read('search')).to eq(state: 'ready', results: partial)
  end

  it 'retries degraded game searches after a minute rather than retaining fallback results for fifteen minutes' do
    allow(MediaSearchService).to receive(:call).and_return([])
    allow(MediaSearchService).to receive(:source_states).and_return([{ source: 'Steam', state: 'unavailable' }])
    allow(GameSearchArtwork).to receive(:call).with([]).and_return([])
    described_class.perform_now('Miles', 'video_game', 'search')
    expect(cache.read('search')).to include(state: 'ready')
    travel 61.seconds do
      expect(cache.read('search')).to be_nil
    end
  end

  it 'skips queued searches superseded by newer input' do
    cache.write('client', 'new-search')
    cache.write('old-search', { state: 'pending' })
    expect(MediaSearchService).not_to receive(:call)
    described_class.perform_now('Tri', 'tv_show', 'old-search', 'client')
    expect(cache.read('old-search')).to be_nil
  end

  it 'records failures so polling does not repeatedly enqueue a broken search' do
    allow(MediaSearchService).to receive(:call).and_raise(StandardError)
    described_class.perform_now('Trivial Pursuit', 'tv_show', 'search')
    expect(cache.read('search')[:state]).to eq('failed')
  end
end
