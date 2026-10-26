# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Review pages', type: :request do
  let!(:author) do
    User.create!(name: 'Alex Reader', username: 'alexreader', email: 'review-page@example.com',
                 password: 'password123', confirmed_at: Time.current)
  end
  let!(:movie) { Movie.create!(title: 'A Very Good Story', release_year: 2026) }
  let!(:entry) do
    LibraryItem.create!(user: author, item: movie, review: "First paragraph.\n\nThe secret ending.",
                        rating: 4.5, is_public: true, consumed: true, consumed_at: Date.new(2026, 10, 20))
  end

  def document
    Nokogiri::HTML(response.body)
  end

  def meta(property)
    document.at_css("meta[property='#{property}']")&.[]('content')
  end

  it 'serves a complete logged-out review with a canonical permalink and separate dates' do
    get public_review_path(entry), params: { tracking: 'ignored' }
    expect(response).to have_http_status(:ok)
    expect(document.at_css('h1').text).to include(movie.title, '2026')
    expect(document.at_css('.review-page-author').text).to include(author.name)
    expect(document.css('.review-page-prose p').map(&:text)).to eq(['First paragraph.', 'The secret ending.'])
    expect(response.body).to include('20 October 2026', 'Review published', '4.5 / 5', 'Copy review link')
    expect(meta('og:url')).to end_with(public_review_path(entry))
    expect(meta('og:url')).not_to include('tracking')
    expect(meta('og:title')).to include(author.name, movie.title)
    expect(meta('og:type')).to eq('article')
    expect(meta('og:description')).to include('4.5 out of 5')
    expect(meta('og:description')).not_to include('secret ending', 'First paragraph')
    expect(document.at_css('meta[name="twitter:description"]')['content']).to eq(meta('og:description'))
    expect(response.headers['Cache-Control']).to include('no-store')
    expect(document.at_css('meta[name="turbo-cache-control"]')['content']).to eq('no-cache')
    expect(response.body).to include("comments_for_LibraryItem_#{entry.id}", "like_button_LibraryItem_#{entry.id}")
  end

  it 'removes access immediately when a formerly public review becomes private' do
    get public_review_path(entry)
    entry.update!(is_public: false)
    get public_review_path(entry)
    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include(entry.review, author.name, movie.title)
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  it 'allows only the owner to read a private page without public sharing metadata' do
    entry.update!(is_public: false)
    post login_path, params: { session: { email: author.email, password: 'password123' } }
    get public_review_path(entry)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('The secret ending.', 'Private review', 'Manage your review')
    expect(response.body).not_to include('Copy review link', 'data-link-share-url-value')
    expect(meta('og:title')).to eq('Private review | Trove')
    expect(meta('og:description')).to eq('This review is private.')
    expect(meta('og:image')).not_to include('A Very Good Story')
    expect(meta('og:url')).not_to include(public_review_path(entry))
    expect(document.at_css('meta[name="robots"]')['content']).to eq('noindex, nofollow')
  end

  it 'denies another signed-in reader access to private reviews' do
    entry.update!(is_public: false)
    reader = User.create!(name: 'Reader', email: 'reader-page@example.com', password: 'password123',
                          confirmed_at: Time.current)
    post login_path, params: { session: { email: reader.email, password: 'password123' } }
    get public_review_path(entry)
    expect(response).to have_http_status(:not_found)
  end

  it 'preserves review links and lists, sanitizes scripts, and keeps all prose out of previews' do
    entry.update!(review: '<ol><li>My first thought</li></ol>' \
                          '<a href="https://example.com/reading">Reading list</a><script>alert(1)</script>')
    get public_review_path(entry)
    expect(document.at_css('.review-page-prose li').text).to eq('My first thought')
    expect(document.at_css('.review-page-prose a')['href']).to eq('https://example.com/reading')
    expect(document.css('.review-page-prose script')).to be_empty
    expect(meta('og:description')).not_to include('My first thought', 'Reading list', 'alert')
  end

  it 'does not fabricate ratings or consumption/publication dates for legacy entries' do
    entry.update_columns(rating: nil, consumed: false, consumed_at: Date.today, review_published_at: nil)
    get public_review_path(entry)
    expect(document.css('.review-page-rating, .review-page-dates time')).to be_empty
    expect(meta('og:description')).not_to include('Rated')
  end

  it 'supports every existing reviewable format with the correct consumption language' do
    show = TvShow.create!(title: 'Series')
    comic = Comic.create!(title: 'Comic')
    media = [show, comic, Album.create!(title: 'Record'), Book.create!(title: 'Novel'), VideoGame.create!(title: 'Game'),
             show.tv_episodes.create!(name: 'Pilot', season: 1, episode: 1),
             comic.comic_issues.create!(title: 'First issue', issue_number: '1')]
    media.each do |item|
      entry.update!(item: item)
      get public_review_path(entry)
      expect(response).to have_http_status(:ok)
      expect(document.at_css('h1').text).to include(item.title)
      expect(document.at_css('.review-page-dates').text).to include(MediaLanguage.for(item)[:past].capitalize)
    end
  end

  it 'never incorporates spoiler-controlled game journal entries or milestones' do
    game = VideoGame.create!(title: 'Game')
    entry.update!(item: game)
    entry.game_journal_entries.create!(body: 'Journal spoiler secret', spoiler: true)
    entry.game_milestones.create!(title: 'Milestone spoiler secret', spoiler: true)
    get public_review_path(entry)
    expect(response.body).not_to include('Journal spoiler secret', 'Milestone spoiler secret')
    expect(entry.game_journal_entries.first).to be_spoiler
    expect(entry.game_milestones.first).to be_spoiler
  end

  it 'returns a neutral not-found response for missing reviews, media, and unsupported types' do
    entry.update!(review: nil)
    get public_review_path(entry)
    expect(response).to have_http_status(:not_found)
    entry.update_columns(review: 'Review', item_type: 'User', item_id: author.id)
    get public_review_path(entry)
    expect(response).to have_http_status(:not_found)
    entry.update_columns(item_type: 'Movie', item_id: movie.id)
    movie.delete
    get public_review_path(entry)
    expect(response).to have_http_status(:not_found)
  end
end
