# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocialPostJob do
  let(:user) do
    User.create!(name: 'Social reader', password: 'password', bsky_access_token: 'bsky-token',
                 bsky_post_activity: true, bsky_post_reviews: true,
                 mastodon_server: 'mastodon.social', mastodon_access_token: 'mastodon-token',
                 mastodon_post_activity: true, mastodon_post_reviews: true)
  end
  let(:movie) { Movie.create!(title: 'A public title') }
  let(:entry) { LibraryItem.create!(user: user, item: movie, is_public: true, review: 'A good film', rating: 4) }
  let(:bluesky) { instance_double(BlueskyClient, post: true) }
  let(:mastodon) { instance_double(MastodonClient, post: true) }

  before do
    allow(BlueskyClient).to receive(:new).and_return(bluesky)
    allow(MastodonClient).to receive(:new).and_return(mastodon)
  end

  it 'delivers public additions to both enabled platforms using a catalog link' do
    described_class.perform_now(entry, 'added')
    expect(bluesky).to have_received(:post).with(a_string_including(movie.title, "/movies/#{movie.id}"), title: movie.title)
    expect(mastodon).to have_received(:post).with(a_string_including(movie.title))
  end

  it 'does not send private reviews' do
    entry.update!(is_public: false)
    described_class.perform_now(entry, 'reviewed')
    expect(bluesky).not_to have_received(:post)
    expect(mastodon).not_to have_received(:post)
  end

  it 'rechecks preferences and disconnected accounts before delivery' do
    entry
    user.update!(bsky_post_activity: false, mastodon_access_token: nil)
    described_class.perform_now(entry.reload, 'added')
    expect(bluesky).not_to have_received(:post)
    expect(mastodon).not_to have_received(:post)
  end

  it 'does not describe watchlist or consumption updates as new additions' do
    %w[watchlist consumed].each { |kind| described_class.perform_now(entry, kind) }
    expect(bluesky).not_to have_received(:post)
    expect(mastodon).not_to have_received(:post)
  end

  it 'continues to Mastodon if Bluesky fails' do
    allow(bluesky).to receive(:post).and_raise(StandardError, 'provider failure')
    described_class.perform_now(entry, 'reviewed')
    expect(mastodon).to have_received(:post).with(a_string_including('A good film'))
  end
end
