# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Editorial::Sync do
  let(:endpoint) { Editorial::Client::ENDPOINT }
  let!(:movie) { Movie.create!(title: 'A movie') }
  let(:post) do
    { 'id' => 42, 'status' => 'publish', 'date_gmt' => '2026-10-20T12:00:00',
      'modified_gmt' => '2026-10-21T12:00:00', 'link' => 'https://tacobout.online/story/',
      'title' => { 'rendered' => 'Story' }, 'excerpt' => { 'rendered' => 'Excerpt', 'protected' => false },
      'content' => { 'rendered' => "<a href='https://trove.schweg.xyz/movies/#{movie.id}'>Movie</a>",
                     'protected' => false } }
  end

  def list_page(page, posts, total: 2)
    stub_request(:get, endpoint).with(query: hash_including('page' => page.to_s))
                                .to_return(body: posts.to_json, headers: { 'X-WP-TotalPages' => total.to_s })
  end

  it 'bounds pages and returns an explicit continuation window, then completes idempotently' do
    list_page(1, [post])
    list_page(2, [post.merge('id' => 43)])
    sync = described_class.new
    result = sync.call(max_pages: 1, per_page: 1, before: '2026-10-24T00:00:00Z')
    expect(result).to include(next_page: 2, before: '2026-10-24T00:00:00Z')
    expect(result).not_to have_key(:watermark)
    result = sync.call(page: result[:next_page], max_pages: 1, per_page: 1, before: result[:before])
    expect(result).to include(next_page: nil, watermark: '2026-10-24T00:00:00Z')
    sync.call(per_page: 1, before: result[:before])
    expect(EditorialArticle.count).to eq(2)
    expect(EditorialArticleTitle.count).to eq(2)
  end

  it 'uses modified-date filters with a one-second overlap for incremental updates' do
    request = stub_request(:get, endpoint).with(query: hash_including(
      'modified_after' => '2026-10-20T23:59:59Z', 'modified_before' => '2026-10-24T00:00:00Z',
      'status' => 'publish', 'context' => 'view', 'orderby' => 'modified', 'order' => 'asc'
    )).to_return(body: [post].to_json, headers: { 'X-WP-TotalPages' => '1' })
    described_class.new.call(after: '2026-10-21T00:00:00Z', before: '2026-10-24T00:00:00Z')
    expect(request).to have_been_requested.once
  end

  it 'withholds the watermark for invalid posts while importing valid neighbors' do
    list_page(1, [post, { 'id' => 43, 'content' => [] }], total: 1)
    report = described_class.new.call
    expect(report[:invalid_ids]).to eq([43])
    expect(report).not_to have_key(:watermark)
    expect(EditorialArticle.count).to eq(1)
  end

  it 'retries transient errors with bounded backoff and keeps the last safe cache' do
    article = Editorial::PostImport.new.call(post)
    request = stub_request(:get, "#{endpoint}/42").with(query: hash_including('_embed' => 'wp:featuredmedia'))
                                                  .to_return(status: 503)
    client = Editorial::Client.new
    allow(client).to receive(:sleep)
    result = described_class.new(client: client).recheck
    expect(result[:unavailable_ids]).to eq([42])
    expect(request).to have_been_requested.times(3)
    expect(client).to have_received(:sleep).with(0.25).once
    expect(client).to have_received(:sleep).with(0.5).once
    expect(article.reload.published).to be true
    expect(article.editorial_article_titles.count).to eq(1)
  end

  [404, 410].each do |status|
    it "suppresses a confirmed HTTP #{status} without retrying" do
      article = Editorial::PostImport.new.call(post)
      request = stub_request(:get, "#{endpoint}/42").with(query: hash_including('context' => 'view'))
                                                    .to_return(status: status)
      expect(described_class.new.recheck[:checked]).to eq(1)
      expect(request).to have_been_requested.once
      expect(article.reload.published).to be false
      expect(article.editorial_article_titles).to be_empty
    end
  end

  it 'preserves cache for 401/403, malformed JSON, and mismatched IDs' do
    article = Editorial::PostImport.new.call(post)
    [{ status: 403 }, { status: 200, body: 'oops' },
     { status: 200, body: post.merge('id' => 99).to_json }].each do |response|
      stub_request(:get, "#{endpoint}/42").with(query: hash_including('context' => 'view')).to_return(response)
      described_class.new.recheck
      expect(article.reload.published).to be true
      expect(EditorialArticle.count).to eq(1)
    end
  end

  it 'bounds the recheck rotation and suppresses public protected responses' do
    article = Editorial::PostImport.new.call(post)
    Editorial::PostImport.new.call(post.merge('id' => 43))
    stub_request(:get, "#{endpoint}/42").with(query: hash_including('context' => 'view'))
                                        .to_return(body: post.deep_merge('content' => { 'protected' => true }).to_json)
    expect(described_class.new.recheck(limit: 1)[:checked]).to eq(1)
    expect(article.reload.published).to be false
    expect(EditorialArticle.find_by!(wordpress_id: 43).published).to be true
  end

  it 'rejects over-budget runs, arbitrary endpoints and redirects without widening shared policy' do
    expect { described_class.new.call(max_pages: 21) }.to raise_error(ArgumentError)
    expect { described_class.new.call(per_page: 51) }.to raise_error(ArgumentError)
    expect { Editorial::Client.validated_uri('https://tacobout.online/wp-admin/') }.to raise_error(MediaSources::Http::Error)
    expect { MediaSources::Http.validated_uri(endpoint) }.to raise_error(MediaSources::Http::Error)
    request = stub_request(:get, endpoint).with(query: hash_including('page' => '1'))
                                          .to_return(status: 302, headers: { 'Location' => 'https://evil.test/' })
    expect { described_class.new.call }.to raise_error(Editorial::Client::Unavailable)
    expect(request).to have_been_requested.once
  end
end
