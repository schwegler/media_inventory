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
