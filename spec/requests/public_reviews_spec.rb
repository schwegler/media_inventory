# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public review API', type: :request do
  let!(:user) { User.create!(name: 'Reviewer', username: 'reviewer', email: 'api@example.com', password: 'password123') }

  def review(**attributes)
    LibraryItem.create!({ user: user, item: Movie.create!(title: 'Example'), review: 'Written review',
                          is_public: true }.merge(attributes))
  end

  def fetch_reviews(**params)
    get '/api/reviews', params: params
    JSON.parse(response.body).fetch('reviews')
  end

  it 'orders by publication with a stable tie-breaker, independent of edits and activity' do
    old = review(review_published_at: 2.days.ago)
    first = review(review_published_at: 1.day.ago)
    second = review(review_published_at: first.review_published_at)
    old.update!(review: 'Edited old review')
    5.times { LibraryItem.create!(user: user, item: Movie.create!(title: 'Added'), is_collected: true) }
    expect(fetch_reviews.map { |r| r['id'] }).to eq([second, first, old].map { |r| "library-item-#{r.id}" })
    expect(old.reload.review_published_at).to be < first.review_published_at
  end

  it 'defaults to three, accepts a limit, caps at twenty, and defaults invalid limits' do
    21.times { review }
    expect(fetch_reviews.size).to eq(3)
    expect(fetch_reviews(limit: 1).size).to eq(1)
    expect(fetch_reviews(limit: 100).size).to eq(20)
    [0, -1, 'invalid', '1.5'].each { |limit| expect(fetch_reviews(limit: limit).size).to eq(3) }
  end

  it 'returns plain text, canonical HTTPS URLs, timestamps, and explicit null optional values' do
    entry = review(review: '<p>Good &amp; fun.</p>')
    data = fetch_reviews.first
    expect(data).to include('body' => 'Good & fun.', 'rating' => nil, 'cover_url' => nil,
                            'rating_scale' => { 'min' => 0, 'max' => 5 }, 'media_type' => 'Movie',
                            'published_at' => entry.review_published_at.utc.iso8601(6),
                            'updated_at' => entry.updated_at.utc.iso8601(6))
    expect(data['reviewer']).to eq('display_name' => 'Reviewer', 'profile_url' => 'https://trove.schweg.xyz/@reviewer')
    expect(data['item_url']).to eq("https://trove.schweg.xyz#{movie_path(entry.item)}")
    expect(data['review_url']).to eq("https://trove.schweg.xyz#{public_review_path(entry)}")
    entry.item.update!(thumbnail_url: 'http://example.com/cover.jpg')
    entry.update!(rating: '4.5')
    expect(fetch_reviews.first).to include('rating' => 4.5, 'cover_url' => "https://trove.schweg.xyz/media/covers/movie/#{entry.item_id}")
  end

  it 'excludes false/null visibility, blank or markup-only bodies, and rating-only entries' do
    review(is_public: false)
    review(is_public: nil)
    [nil, '', " \n\t", '<p> </p>'].each { |body| review(review: body, rating: '5') }
    expect(fetch_reviews).to eq([])
  end

  it 'ignores logged-in owner privileges and native auto-login' do
    review(is_public: false)
    post login_path, params: { session: { email: user.email, password: 'password123' } }
    get '/api/reviews', headers: { 'User-Agent' => 'MediaInventoryDesktop' }
    expect(JSON.parse(response.body)['reviews']).to eq([])
    expect(response.headers['Set-Cookie']).to be_nil
  end

  it 'excludes deleted users, deleted media, missing parents, and unsupported types before limiting' do
    valid = review
    review.item.delete
    orphan = review
    ActiveRecord::Base.connection.disable_referential_integrity { orphan.update_columns(user_id: 999_999) }
    show = TvShow.create!(title: 'Show')
    episode = show.tv_episodes.create!(name: 'Episode', season: 1, episode: 1)
    review(item: episode)
    ActiveRecord::Base.connection.disable_referential_integrity { show.delete }
    comic = Comic.create!(title: 'Comic')
    issue = comic.comic_issues.create!(title: 'Issue', issue_number: '1')
    review(item: issue)
    ActiveRecord::Base.connection.disable_referential_integrity { comic.delete }
    review.update_columns(item_type: 'User', item_id: user.id)
    expect(fetch_reviews(limit: 1).map { |r| r['id'] }).to eq(["library-item-#{valid.id}"])
  end

  it 'revalidates ETags against current visibility and deletion, including empty responses' do
    entry = review
    fetch_reviews
    etag = response.headers['ETag']
    expect(response.headers['Cache-Control']).to include('public', 'no-cache')
    get '/api/reviews', headers: { 'If-None-Match' => etag }
    expect(response).to have_http_status(:not_modified)
    entry.update!(is_public: false)
    get '/api/reviews', headers: { 'If-None-Match' => etag }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['reviews']).to eq([])
    entry.update!(is_public: true)
    fetch_reviews
    etag = response.headers['ETag']
    entry.item.delete
    get '/api/reviews', headers: { 'If-None-Match' => etag }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['reviews']).to eq([])
  end

  it 'preloads media, covers, reviewers, and child parents without per-review queries' do
    show = TvShow.create!(title: 'Show')
    6.times do |number|
      review(item: show.tv_episodes.create!(name: 'Episode', season: 1, episode: number + 1))
    end
    queries = []
    subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, event|
      queries << event[:sql] if event[:sql].start_with?('SELECT') && !event[:cached]
    end
    begin
      expect(fetch_reviews(limit: 20).size).to eq(6)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end
    expect(queries.grep(/FROM "tv_shows"/).size).to eq(1)
    expect(queries.grep(/FROM "tv_episodes"/).size).to eq(1)
    expect(queries.grep(/FROM "users"/).size).to eq(1)
  end

  it 'serves each supported media type and excludes reviews after user deletion' do
    media = [Movie.create!(title: 'Movie'), TvShow.create!(title: 'TV'), Album.create!(title: 'Album'),
             Comic.create!(title: 'Comic'), VideoGame.create!(title: 'Game'), Book.create!(title: 'Book')]
    media << media[1].tv_episodes.create!(name: 'Episode', season: 1, episode: 1)
    media << media[3].comic_issues.create!(title: 'Issue', issue_number: '1')
    media << media[2].album_tracks.create!(title: 'Track', provider_id: 'synthetic:1', disc_number: 1, track_number: 1)
    edition = media[5].book_editions.create!(identity_key: 'manual:test', label: 'Test edition', format: 'ebook')
    media << edition.book_chapters.create!(identity_key: 'manual:first', position: 0, title: 'Prologue')
    media.each { |item| review(item: item) }
    expect(fetch_reviews(limit: 20).map { |r| r['media_type'] }).to match_array(ReviewsController::REVIEWABLE_MODELS.keys)
    user.destroy!
    expect(fetch_reviews).to eq([])
  end

  it 'timestamps first written public publication and preserves it across hiding and republishing' do
    entry = review(is_public: false)
    expect(entry.review_published_at).to be_nil
    entry.update!(is_public: true)
    published = entry.review_published_at
    entry.update!(is_public: false)
    entry.update!(is_public: true, review: 'New wording')
    expect(entry.review_published_at).to eq(published)
  end
end
