# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaSources::Http do
  it 'blocks internal hosts, deceptive suffixes, credentials, and non-HTTPS URLs' do
    %w[http://covers.openlibrary.org/a https://127.0.0.1/a https://covers.openlibrary.org.evil.test/a
       https://user:pass@covers.openlibrary.org/a https://covers.openlibrary.org:8443/a].each do |url|
      expect { described_class.get(url) }.to raise_error(described_class::Error)
    end
  end

  it 'validates each redirect target' do
    stub_request(:get, 'https://covers.openlibrary.org/a').to_return(status: 302,
                                                                     headers: { location: 'http://169.254.169.254/' })
    expect { described_class.get('https://covers.openlibrary.org/a') }.to raise_error(described_class::Error)
  end

  it 'enforces the byte limit even without Content-Length' do
    stub_request(:get, 'https://covers.openlibrary.org/a').to_return(body: 'a' * 20)
    expect { described_class.get('https://covers.openlibrary.org/a', max_bytes: 10) }.to raise_error(described_class::Error)
  end
end

RSpec.describe MediaSources::Http do
  it 'rejects private, credential-bearing, unapproved and insecure image URLs' do
    ['http://media.rawg.io/cover.jpg', 'https://127.0.0.1/image', 'https://localhost/image',
     'https://steamstatic.com.evil.example/image', 'https://user:pass@media.rawg.io/image',
     'https://media.rawg.io:8443/image'].each do |url|
      expect { described_class.get(url) }.to raise_error(described_class::Error)
    end
  end
  it 'does not forward provider authorization through a cross-host redirect' do
    target = 'https://cdn2.steamgriddb.com/grid/test.png'
    stub_request(:get, 'https://www.steamgriddb.com/api/v2/test').with(headers: { 'Authorization' => 'Bearer test' })
                                                                 .to_return(status: 302, headers: { 'Location' => target })
    stub_request(:get, 'https://cdn2.steamgriddb.com/grid/test.png').with { |request| !request.headers.key?('Authorization') }
                                                                    .to_return(body: 'image')
    expect(described_class.get('https://www.steamgriddb.com/api/v2/test',
                               options: { headers: { 'Authorization' => 'Bearer test' } })).to eq('image')
  end
  it 'rejects redirects outside trusted providers' do
    stub_request(:get, 'https://media.rawg.io/test').to_return(status: 302,
                                                               headers: { 'Location' => 'https://127.0.0.1/private' })
    expect { described_class.get('https://media.rawg.io/test') }.to raise_error(described_class::Error)
  end
end

RSpec.describe 'Provider response caching' do
  let(:url) { 'https://api.tvmaze.com/shows/42' }

  it 'reuses fresh responses and revalidates stale responses with their ETag' do
    stub_request(:get, url).to_return(body: '{"name":"Show"}', headers: { 'ETag' => 'version-1' })
    expect(MediaSources::Http.cached_get(url, expires_in: 0.seconds)).to eq('{"name":"Show"}')
    stub_request(:get, url).with(headers: { 'If-None-Match' => 'version-1' }).to_return(status: 304)
    expect(MediaSources::Http.cached_get(url)).to eq('{"name":"Show"}')
    MediaSources::Http.cached_get(url)
    expect(WebMock).to have_requested(:get, url).twice
  end

  it 'does not cache malformed JSON' do
    stub_request(:get, url).to_return(body: '<html>Error</html>')
    expect { MediaSources::Http.cached_get(url) }.to raise_error(JSON::ParserError)
    stub_request(:get, url).to_return(body: '{"name":"Recovered"}')
    expect(MediaSources::Http.cached_get(url)).to eq('{"name":"Recovered"}')
  end
end
