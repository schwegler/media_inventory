# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ordered child reviews', type: :request do
  let!(:author) do
    User.create!(name: 'Author', email: 'child-author@example.com', password: 'password123', confirmed_at: Time.current)
  end
  let!(:other) do
    User.create!(name: 'Other', email: 'child-other@example.com', password: 'password123', confirmed_at: Time.current)
  end
  let!(:album) { Album.create!(title: 'Two discs') }
  let!(:tracks) do
    [[1, 1], [1, 2], [1, 3], [2, 1], [2, 2]].map.with_index do |(disc, number), index|
      album.album_tracks.create!(provider_id: "test:#{index}", title: "Track #{index}", disc_number: disc,
                                 track_number: number)
    end
  end

  def review(item, user: author, public: true)
    LibraryItem.create!(user: user, item: item, review: "Review #{item.title}", is_public: public)
  end

  def login(user)
    post login_path, params: { session: { email: user.email, password: 'password123' } }
  end

  it 'skips absent, private and other-author reviews across discs and links to the same author parent' do
    first = review(tracks[0])
    hidden = review(tracks[2], public: false)
    last = review(tracks[4])
    review(tracks[1], user: other)
    parent = review(album)
    get public_review_path(first)
    expect(response).to have_http_status(:ok)
    nav = Nokogiri::HTML(response.body).at_css('.child-review-navigation')
    expect(nav.css('a').map { |a| a['href'] }).to eq([public_review_path(last)])
    expect(response.body).to include(public_review_path(parent))
    expect(response.body).not_to include(public_review_path(hidden))
    login(author)
    get public_review_path(first)
    expect(response.body).to include(public_review_path(hidden))
    get public_review_path(last)
    expect(Nokogiri::HTML(response.body).at_css('[rel="prev"]')['href']).to eq(public_review_path(hidden))
  end

  it 'lists only visible reviews by the parent author and rechecks revoked visibility' do
    parent = review(album)
    child = review(tracks[1])
    hidden = review(tracks[2], public: false)
    unrelated = review(tracks[3], user: other)
    get public_review_path(parent)
    expect(response.body).to include(public_review_path(child))
    expect(response.body).not_to include(public_review_path(hidden), public_review_path(unrelated))
    child.update!(is_public: false)
    get public_review_path(parent)
    expect(response.body).not_to include(public_review_path(child), 'This author’s child reviews')
    get public_review_path(child)
    expect(response).to have_http_status(:not_found)
  end

  it 'saves track reviews through the existing modal without altering the album rating or IDs' do
    parent = LibraryItem.create!(user: author, item: album, rating: 5, consumed: true)
    login(author)
    get edit_review_path(item_type: 'AlbumTrack', item_id: tracks[0].id)
    expect(response.body).to include('Your review', tracks[0].title)
    2.times do
      patch review_path,
            params: { item_type: 'AlbumTrack', item_id: tracks[0].id, review: 'A track review',
                      rating: 2, is_public: '1' }, as: :turbo_stream
      expect(response).to have_http_status(:ok)
    end
    expect(author.library_items.where(item: tracks[0]).count).to eq(1)
    expect(parent.reload.rating).to eq('5')
    expect(parent).to be_consumed
    expect(ConsumptionPass.count).to eq(0)
    get album_track_path(tracks[0])
    expect(response.body).to include('A track review', 'Read full review')
    get '/api/reviews'
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['reviews'].map { |r| r['media_type'] }).to include('AlbumTrack')
  end

  it 'rejects missing child parents and unsupported review IDs' do
    entry = review(tracks.first)
    ActiveRecord::Base.connection.disable_referential_integrity { album.delete } # emulate a dangling legacy parent
    get public_review_path(entry)
    expect(response).to have_http_status(:not_found)
  end

  it 'preserves reviewed track identities and omitted rows during partial and conflicting metadata refreshes' do
    entry = review(tracks.first)
    ids = album.album_tracks.order(:id).pluck(:id)
    row = { 'provider_id' => tracks.first.provider_id, 'title' => 'Changed title',
            'disc_number' => 1, 'track_number' => 1 }
    expect(AlbumMetadata.reconcile(album, [row])).to eq(0)
    expect(album.album_tracks.order(:id).pluck(:id)).to eq(ids)
    expect(entry.reload.item).to eq(tracks.first)
    expect do
      AlbumMetadata.reconcile(album, [{ 'provider_id' => 'a-different-edition', 'title' => 'Replacement',
                                        'disc_number' => 1, 'track_number' => 1 }])
    end.to raise_error(AlbumMetadata::EditionConflict)
    expect(album.album_tracks.order(:id).pluck(:id)).to eq(ids)
  end

  it 'navigates sparse TV and comic reviews by the same author' do
    show = TvShow.create!(title: 'Synthetic show')
    comic = Comic.create!(title: 'Synthetic comic')
    episode_one = show.tv_episodes.create!(name: 'First', season: 1, episode: 1)
    episode_two = show.tv_episodes.create!(name: 'Final', season: 2, episode: 1)
    issue_one = comic.comic_issues.create!(title: 'First', issue_number: 1)
    issue_two = comic.comic_issues.create!(title: 'Final', issue_number: 8)
    [[show, episode_one, episode_two], [comic, issue_one, issue_two]].each do |parent_item, first, last|
      parent = review(parent_item)
      first_entry = review(first)
      last_entry = review(last)
      get public_review_path(first_entry)
      expect(response.body).to include(public_review_path(last_entry), public_review_path(parent))
      get public_review_path(last_entry)
      expect(Nokogiri::HTML(response.body).at_css('[rel="prev"]')['href']).to eq(public_review_path(first_entry))
    end
  end

  it 'orders unnumbered tracks stably after known positions' do
    unknown = album.album_tracks.create!(title: 'Unknown position', provider_id: 'test:unknown')
    expect(OrderedReviewChildren.children(album).last).to eq(unknown)
  end
end
