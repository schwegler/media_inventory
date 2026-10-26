# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Review excerpts', type: :request do
  let!(:author) do
    User.create!(name: 'A Reader', username: 'areader', email: 'excerpt-author@example.com', password: 'password123',
                 confirmed_at: Time.current)
  end
  let!(:album) { Album.create!(title: 'CONFESSIONS II', artist: 'Madonna', release_year: 2026) }
  let!(:entry) do
    LibraryItem.create!(user: author, item: album, is_public: true,
                        review: "Opening paragraph.\n\n#{'A thoughtful sentence. ' * 80}\n\nTHE FULL ENDING")
  end

  it 'bounds community reviews, links to their full page, and preserves stored content' do
    original = entry.review
    get album_path(album)
    doc = Nokogiri::HTML(response.body)
    preview = doc.at_css('.show-review-card .review-excerpt')
    expect(preview.text).not_to include('THE FULL ENDING')
    link = preview.at_css('a.review-excerpt-link')
    expect(link['href']).to eq(public_review_path(entry))
    expect(link.text).to eq('Read full review')
    expect(link['aria-label']).to include(author.name, album.title)
    expect(link['data-turbo-frame']).to eq('_top')
    get public_review_path(entry)
    expect(response.body).to include('THE FULL ENDING')
    expect(entry.reload.review).to eq(original)
  end

  it 'bounds a Madonna-style twelve-paragraph album review while the full page retains every paragraph' do
    body = (1..12).map { |number| "Paragraph #{number}. #{'A synthetic album listening note. ' * 25}" }.join("\n\n")
    entry.update!(review: body, rating: 4.5)
    get album_path(album)
    preview = Nokogiri::HTML(response.body).at_css('.show-review-card .review-excerpt')
    expect(preview.at_css('.review-excerpt-text').text.strip.each_grapheme_cluster.count).to be <= 481
    expect(preview.css('p').length).to be <= 3
    expect(preview.text).not_to include('Paragraph 12.')
    expect(preview.at_css('.review-excerpt-link')['href']).to eq(public_review_path(entry))
    get public_review_path(entry)
    expect(Nokogiri::HTML(response.body).css('.review-page-prose p').length).to eq(12)
    expect(response.body).to include('Paragraph 12.')
    expect(entry.reload.review).to eq(body)
  end

  it 'renders balanced nested HTML, whole Unicode clusters, and no omitted active links' do
    entry.update!(review: "<strong><em><a href=\"https://example.com/visible\">#{'👩🏽‍🚀 café é ' * 100}</a></em></strong>" \
                          '<a href="https://example.com/omitted">OMITTED ACTIVE LINK</a>')
    original = entry.review
    get album_path(album)
    raw = response.body.match(%r{<div class="review-excerpt-text">(.*?)</div>}m)[1]
    fragment = Nokogiri::HTML5.fragment(raw, max_errors: 100)
    expect(fragment.errors).to be_empty
    expect(fragment.at_css('strong em a')['href']).to eq('https://example.com/visible')
    expect(fragment.text.strip.each_grapheme_cluster.count).to be <= 481
    expect(fragment.text).to be_valid_encoding
    expect(raw).not_to include('https://example.com/omitted', 'OMITTED ACTIVE LINK')
    expect(entry.reload.review).to eq(original)
  end

  it 'shows complete short reviews without a redundant full-review link' do
    entry.update!(review: "One short paragraph.\n\nAnother thought with <a href=\"https://example.com\">a link</a>.")
    get album_path(album)
    preview = Nokogiri::HTML(response.body).at_css('.show-review-card .review-excerpt')
    expect(preview.css('p').map(&:text)).to eq(['One short paragraph.', 'Another thought with a link.'])
    expect(preview.at_css('a')['href']).to eq('https://example.com')
    expect(preview.css('.review-excerpt-link')).to be_empty
  end

  it 'keeps private excerpts and review URLs out of public media, profiles and feeds' do
    entry.update!(is_public: false)
    [album_path(album), user_path(author), root_path].each do |path|
      get path
      expect(response.body).not_to include('Opening paragraph.', 'THE FULL ENDING', public_review_path(entry))
    end
  end

  it 'bounds dashboard and popular review feeds and links to the review rather than the media' do
    reader = User.create!(name: 'Feed reader', email: 'excerpt-feed@example.com', password: 'password123',
                          confirmed_at: Time.current)
    post login_path, params: { session: { email: reader.email, password: 'password123' } }
    get root_path
    previews = Nokogiri::HTML(response.body).css('.review-excerpt')
    expect(previews).not_to be_empty
    previews.each do |preview|
      expect(preview.at_css('.review-excerpt-text').text.strip.each_grapheme_cluster.count).to be <= 221
      expect(preview.at_css('.review-excerpt-link')['href']).to eq(public_review_path(entry))
    end
    expect(response.body).not_to include('THE FULL ENDING')
  end

  it 'uses the same bounded renderer for the owner summary and Turbo review updates' do
    post login_path, params: { session: { email: author.email, password: 'password123' } }
    get album_path(album)
    summaries = Nokogiri::HTML(response.body).css('#my-library .review-excerpt, .show-review .review-excerpt')
    expect(summaries.size).to eq(2)
    expect(summaries.map(&:text).join).not_to include('THE FULL ENDING')
    patch review_path, params: { item_type: 'Album', item_id: album.id, review: entry.review, is_public: '1' },
                       headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Read full review', public_review_path(entry))
    fragments = Nokogiri::HTML(response.body).css('.review-excerpt').map(&:text)
    expect(fragments).not_to be_empty
    expect(fragments.join).not_to include('THE FULL ENDING')
  end
end
