# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Review event permalinks', type: :request do
  let!(:author) do
    User.create!(name: 'Album reviewer', username: 'albumreviewer', email: 'review-feed-author@example.com',
                 password: 'password123', confirmed_at: Time.current)
  end
  let!(:album) { Album.create!(title: 'CONFESSIONS II', artist: 'Madonna', release_year: 2026) }
  let!(:entry) { LibraryItem.create!(user: author, item: album, is_public: true, review: 'A short, complete review.') }

  def expect_review_link(scope)
    expect(scope.css("a[href='#{public_review_path(entry)}']").map(&:text)).to include('View review')
    expect(scope.text).to include('A short, complete review.')
    expect(scope.css('.review-excerpt-link').first['aria-label']).to include(author.name, album.title)
  end

  it 'links short reviews in the logged-out general activity feed' do
    get root_path
    card = Nokogiri::HTML(response.body).at_css('.activity-card')
    expect_review_link(card)
    expect(card.at_css('a.activity-item-link')['href']).to eq(album_path(album))
  end

  it 'links short reviews in both dashboard discovery and popular-review feeds' do
    reader = User.create!(name: 'Reader', email: 'review-feed-reader@example.com', password: 'password123',
                          confirmed_at: Time.current)
    post login_path, params: { session: { email: reader.email, password: 'password123' } }
    get root_path
    doc = Nokogiri::HTML(response.body)
    expect_review_link(doc.at_css('.dashboard-circle-entry'))
    expect_review_link(doc.at_css('.popular-review-row'))
  end

  it 'links profile overview and Activity tabs, including legacy catalog-backed events' do
    Activity.create!(user: author, trackable: album, activity_type: 'reviewed')
    [user_path(author), user_path(author, tab: 'posts')].each do |path|
      get path
      follow_redirect! if response.redirect?
      cards = Nokogiri::HTML(response.body).css('.activities-feed .activity-card')
      expect(cards.length).to eq(2)
      cards.each { |card| expect_review_link(card) }
    end
  end

  it 'keeps private text and permalinks out of general, dashboard and public-preview feeds' do
    entry.update!(is_public: false)
    Activity.create!(user: author, trackable: album, activity_type: 'reviewed')
    [root_path, user_path(author, tab: 'posts')].each do |path|
      get path
      follow_redirect! if response.redirect?
      expect(response.body).not_to include(entry.review, public_review_path(entry))
    end
    post login_path, params: { session: { email: author.email, password: 'password123' } }
    get user_path(author, tab: 'posts')
    follow_redirect! if response.redirect?
    expect_review_link(Nokogiri::HTML(response.body).at_css('.activity-card'))
    get user_path(author, tab: 'posts', preview: 'public')
    follow_redirect! if response.redirect?
    expect(response.body).not_to include(entry.review, public_review_path(entry))
  end

  it 'links liked written reviews on profiles without exposing private review links to visitors' do
    author.likes.create!(likeable: entry)
    get user_path(author, tab: 'likes')
    follow_redirect! if response.redirect?
    link = Nokogiri::HTML(response.body).at_css('.profile-like-row a')
    expect(link['href']).to eq(public_review_path(entry))
    expect(link.text).to include('Review of', album.title)
    entry.update!(is_public: false)
    get user_path(author, tab: 'likes')
    follow_redirect! if response.redirect?
    expect(response.body).not_to include(public_review_path(entry))
  end

  it 'adds the canonical review URL to the public JSON feed without truncating its body contract' do
    get '/api/reviews'
    review = JSON.parse(response.body).fetch('reviews').first
    expect(review['review_url']).to eq("https://trove.schweg.xyz#{public_review_path(entry)}")
    expect(review['item_url']).to eq("https://trove.schweg.xyz#{album_path(album)}")
    expect(review['body']).to eq(entry.review)
  end

  it 'batch-loads episode parents in the ActivityPub review feed' do
    show = TvShow.create!(title: 'Series')
    6.times do |number|
      episode = show.tv_episodes.create!(name: 'Episode', season: 1, episode: number + 1)
      LibraryItem.create!(user: author, item: episode, is_public: true, review: 'An episode review.')
    end
    queries = []
    subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, event|
      queries << event[:sql] if event[:sql].start_with?('SELECT') && !event[:cached]
    end
    begin
      get activitypub_outbox_path(author.id)
      expect(JSON.parse(response.body)['orderedItems'].length).to eq(7)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end
    expect(queries.grep(/FROM "tv_shows"/).length).to eq(1)
    expect(queries.grep(/FROM "tv_episodes"/).length).to eq(1)
  end

  it 'links public reviews in ActivityPub while excluding private and unsupported entries' do
    unsupported = LibraryItem.create!(user: author, item: Movie.create!(title: 'Ignored'),
                                      is_public: true, review: 'UNSUPPORTED REVIEW')
    unsupported.update_columns(item_type: 'User', item_id: author.id)
    get activitypub_outbox_path(author.id)
    objects = JSON.parse(response.body)['orderedItems'].map { |activity| activity['object'] }
    expect(objects.size).to eq(1)
    expect(response.body).not_to include('UNSUPPORTED REVIEW')
    expect(objects.first['url']).to eq("https://trove.schweg.xyz#{public_review_path(entry)}")
    expect(objects.first['content']).to include('View review')
    entry.update!(is_public: false)
    get activitypub_outbox_path(author.id)
    expect(JSON.parse(response.body)['orderedItems']).to eq([])
    expect(response.body).not_to include(entry.review, public_review_path(entry))
  end
end
