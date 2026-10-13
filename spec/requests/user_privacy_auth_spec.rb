# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authorization Bypass', type: :request do
  let(:owner) { User.create!(name: 'Owner', email: 'owner@example.com', password: 'password', username: 'owner') }
  let(:visitor) { User.create!(name: 'Visitor', email: 'visitor@example.com', password: 'password', username: 'visitor') }
  let(:movie) { Movie.create!(title: 'Private Movie') }
  let(:library_item) { LibraryItem.create!(user: owner, item: movie, is_collected: true, is_public: false) }
  let(:comment) { Comment.create!(user: owner, commentable: library_item, content: 'Secret') }
  let(:activity) { Activity.create!(user: owner, trackable: library_item, activity_type: 'added') }

  before do
    post login_path, params: { session: { email: visitor.email, password: 'password' } }
  end

  it 'should not allow liking a comment on a private library item' do
    post toggle_like_path, params: { likeable_type: 'Comment', likeable_id: comment.id }, xhr: true
    expect(response).to have_http_status(:forbidden)
  end

  it 'should not allow liking an activity on a private library item' do
    post toggle_like_path, params: { likeable_type: 'Activity', likeable_id: activity.id }, xhr: true
    expect(response).to have_http_status(:forbidden)
  end
end
