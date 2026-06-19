# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comment, type: :model do
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com', password: 'password') }
  let(:movie) { Movie.create!(title: 'Inception') }
  let!(:library_item) { LibraryItem.create!(user: user, item: movie) }

  it 'is valid with content, user and commentable' do
    comment = Comment.new(content: 'Great movie!', user: user, commentable: movie)
    expect(comment).to be_valid
  end

  it 'is invalid without content' do
    comment = Comment.new(content: '', user: user, commentable: movie)
    expect(comment).not_to be_valid
  end
end
