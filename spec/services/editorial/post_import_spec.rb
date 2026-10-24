# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Editorial::PostImport do
  let!(:movie) { Movie.create!(title: 'Fixture movie') }
  let!(:book) { Book.create!(title: 'Fixture book') }
  let(:importer) { described_class.new }
  let(:post) do
    { 'id' => 123, 'status' => 'publish', 'date_gmt' => '2026-10-20T12:00:00',
      'modified_gmt' => '2026-10-21T12:00:00', 'link' => 'https://tacobout.online/2026/story/',
      'title' => { 'rendered' => 'A &amp; B <em>roundup</em>' },
      'excerpt' => { 'rendered' => '<p>Some perspective.</p>', 'protected' => false },
      'content' => { 'rendered' => "<a href='https://trove.schweg.xyz/movies/#{movie.to_param}'>Film</a>",
                     'protected' => false },
      '_embedded' => { 'wp:featuredmedia' => [{ 'source_url' => 'https://i0.wp.com/tacobout.online/wp-content/uploads/2026/10/story.jpg?fit=1200%2C675&ssl=1' }] } }
  end

  it 'upserts stable IDs and de-duplicates links in multi-title roundups' do
    post['content']['rendered'] *= 2
    post['content']['rendered'] += "<a href='https://trove.schweg.xyz/books/#{book.id}'>Book</a>"
    2.times { importer.call(post) }
    expect(EditorialArticle.count).to eq(1)
    expect(EditorialArticleTitle.count).to eq(2)
    expect(EditorialArticle.for_title(movie).sole.title).to eq('A & B roundup')
    expect(EditorialArticle.for_title(book).sole.wordpress_id).to eq(123)
    expect(LibraryItem.count).to eq(0)
  end

  it 'updates all metadata and replaces stale title associations' do
    article = importer.call(post)
    post.merge!('title' => { 'rendered' => 'Revised' }, 'link' => 'https://tacobout.online/revised/',
                'modified_gmt' => '2026-10-22T12:00:00', '_embedded' => nil)
    post['excerpt']['rendered'] = nil
    post['content']['rendered'] = "<a href='https://trove.schweg.xyz/books/#{book.id}'>Book</a>"
    importer.call(post)
    expect(article.reload).to have_attributes(title: 'Revised', canonical_url: 'https://tacobout.online/revised/',
                                              excerpt: '', image_url: nil)
    expect(EditorialArticle.for_title(movie)).to be_empty
    expect(EditorialArticle.for_title(book).sole).to eq(article)
  end

  it 'ignores unresolved, relative, wrapped, lookalike, non-title and unsafe URLs without fuzzy matching' do
    links = ['https://trove.schweg.xyz/movies/999999999', "https://trove.schweg.xyz.evil.test/movies/#{movie.id}",
             "https://evil.test/movies/#{movie.id}", "http://trove.schweg.xyz/movies/#{movie.id}",
             "https://trove.schweg.xyz@evil.test/movies/#{movie.id}", "/movies/#{movie.id}",
             "https://trove.schweg.xyz/movies/#{movie.id}?edit=1", 'https://trove.schweg.xyz/entities/1',
             "https://trove.schweg.xyz/movies/\n#{movie.id}", 'javascript:alert(1)']
    post['content']['rendered'] = links.map { |url| "<a href='#{url}'>#{movie.title}</a>" }.join
    importer.call(post)
    expect(EditorialArticleTitle.count).to eq(0)
  end

  it 'strips executable markup and bounds text, rejecting unsafe links and image hosts' do
    post['title']['rendered'] = '<script>alert(1)</script><img src=x onerror=alert(2)>Safe &amp; sound'
    post['excerpt']['rendered'] = "<style>evil</style>#{'words ' * 300}"
    post['_embedded']['wp:featuredmedia'][0]['source_url'] = 'https://evil.test/track.png'
    article = importer.call(post)
    expect(article.title).to eq('Safe & sound')
    expect(article.excerpt.length).to be <= 600
    expect(article.image_url).to be_nil
    post['link'] = 'javascript:alert(1)'
    expect { importer.call(post) }.to raise_error(described_class::Invalid)
    expect(article.reload.canonical_url).to eq('https://tacobout.online/2026/story/')
  end

  it 'suppresses confirmed unpublishing and clears associations, allowing later republication' do
    article = importer.call(post)
    %w[draft private trash pending future].each do |status|
      importer.call(post.merge('status' => status))
      expect(article.reload.published).to be false
      expect(article.editorial_article_titles).to be_empty
      importer.call(post)
      expect(article.reload.published).to be true
    end
    post['content']['protected'] = true
    importer.call(post)
    expect(article.reload.published).to be false
    expect(article.editorial_article_titles).to be_empty
  end

  it 'does not create protected posts and preserves cache for malformed metadata' do
    expect(importer.call(post.deep_merge('excerpt' => { 'protected' => true }))).to be_nil
    article = importer.call(post)
    [post.merge('content' => []), post.merge('status' => nil), post.merge('date_gmt' => 'oops'),
     post.deep_merge('content' => { 'protected' => nil })].each do |invalid|
      expect { importer.call(invalid) }.to raise_error(described_class::Invalid)
      expect(article.reload.published).to be true
      expect(article.editorial_article_titles.count).to eq(1)
    end
    importer.call(post.merge('_embedded' => ['malformed']))
    expect(article.reload.image_url).to be_nil
  end

  it 'does not overwrite a more recently modified cached post with an older response' do
    article = importer.call(post)
    importer.call(post.merge('modified_gmt' => '2026-10-19T12:00:00', 'title' => { 'rendered' => 'Old' }))
    expect(article.reload.title).to eq('A & B roundup')
  end
end
