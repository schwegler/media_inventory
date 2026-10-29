# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Editorial::Client do
  let(:client) { described_class.new }
  let(:url) { "#{described_class::ENDPOINT}/12" }

  before { allow(client).to receive(:sleep) }

  it 'retries timeouts within a fixed attempt budget' do
    request = stub_request(:get, url).with(query: hash_including('context' => 'view')).to_timeout
    expect { client.fetch(id: 12, params: { context: 'view' }) }.to raise_error(described_class::Unavailable)
    expect(request).to have_been_requested.times(3)
  end

  it 'backs off on rate limiting and can recover' do
    request = stub_request(:get, url).with(query: hash_including('_embed' => 'wp:featuredmedia'))
                                     .to_return(status: 429).then.to_return(body: { id: 12 }.to_json)
    expect(client.fetch(id: 12)).to eq('id' => 12)
    expect(request).to have_been_requested.twice
    expect(client).to have_received(:sleep).with(0.25).once
  end

  it 'rejects oversized bodies and malformed pagination metadata' do
    stub_request(:get, url).with(query: hash_including('_embed' => 'wp:featuredmedia'))
                           .to_return(body: 'x' * (MediaSources::Http::MAX_JSON_BYTES + 1))
    expect { client.fetch(id: 12) }.to raise_error(described_class::Unavailable)
    stub_request(:get, described_class::ENDPOINT).with(query: hash_including('_embed' => 'wp:featuredmedia'))
                                                 .to_return(body: '[]')
    expect { client.fetch }.to raise_error(described_class::Unavailable, /pagination/)
  end

  it 'rejects credentials, lookalike hosts, alternate ports and non-HTTPS endpoints' do
    ['http://tacobout.online/wp-json/wp/v2/posts', 'https://tacobout.online.evil.test/wp-json/wp/v2/posts',
     'https://user:password@tacobout.online/wp-json/wp/v2/posts',
     'https://tacobout.online:8443/wp-json/wp/v2/posts'].each do |endpoint|
      expect { described_class.validated_uri(endpoint) }.to raise_error(MediaSources::Http::Error)
    end
  end
end
