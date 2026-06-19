# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Like, type: :model do
  let(:user) { User.create!(name: 'Test', email: 'test@example.com', password: 'password') }
  let(:movie) { Movie.create!(title: 'Inception') }
  let!(:library_item) { LibraryItem.create!(user: user, item: movie) }

  it 'is valid with user and likeable' do
    like = Like.new(user: user, likeable: movie)
    expect(like).to be_valid
  end

  it 'requires a user' do
    like = Like.new(likeable: movie)
    expect(like).not_to be_valid
  end

  it 'requires a likeable' do
    like = Like.new(user: user)
    expect(like).not_to be_valid
  end

  it 'enforces uniqueness of user scoped to likeable' do
    Like.create!(user: user, likeable: movie)
    duplicate_like = Like.new(user: user, likeable: movie)
    expect(duplicate_like).not_to be_valid
  end
end
