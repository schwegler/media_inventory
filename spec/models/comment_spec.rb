# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comment, type: :model do
  let(:user) do
    User.create!(
      name: 'Example User',
      email: 'user@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end
  let(:movie) { Movie.create!(title: 'Inception', user: user) }

  it 'is valid with content, user and commentable' do
    comment = Comment.new(content: 'Great movie!', user: user, commentable: movie)
    expect(comment).to be_valid
  end

  it 'is invalid without content' do
    comment = Comment.new(content: '', user: user, commentable: movie)
    expect(comment).not_to be_valid
  end
end
