# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LibraryItem, type: :model do
  it 'is valid with valid attributes' do
    user = User.create!(name: 'Test', email: "test_#{SecureRandom.hex(4)}@test.com", password: 'password',
                        password_confirmation: 'password')
    album = Album.create!(title: 'Test Album')
    item = LibraryItem.new(user: user, item: album)
    expect(item).to be_valid
  end
  it 'posts an existing review when it becomes public, without reposting unrelated edits' do
    user = User.create!(name: 'Reader', password: 'password')
    movie = Movie.create!(title: 'A film')
    entry = LibraryItem.create!(user: user, item: movie, review: 'Good film', is_public: false)
    allow(SocialPostJob).to receive(:perform_later)

    entry.update!(is_public: true)
    expect(SocialPostJob).to have_received(:perform_later).with(entry, 'reviewed').once

    entry.update!(consumed_at: Date.current)
    expect(SocialPostJob).to have_received(:perform_later).with(entry, 'reviewed').once
  end
end
