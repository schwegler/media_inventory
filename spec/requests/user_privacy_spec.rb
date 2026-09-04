# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Profile Privacy', type: :request do
  let(:owner) { User.create!(name: 'Owner', email: 'owner@example.com', password: 'password', username: 'owner') }
  let(:visitor) do
    User.create!(name: 'Visitor', email: 'visitor@example.com', password: 'password', username: 'visitor')
  end
  let(:movie) { Movie.create!(title: 'Private Movie') }
  let!(:library_item) { LibraryItem.create!(user: owner, item: movie, is_collected: true, is_public: false) }

  before do
    post login_path, params: { session: { email: visitor.email, password: 'password' } }
  end

  it 'does not show private items to other users' do
    get user_path(owner)
    expect(response.body).not_to include('Private Movie')
  end

  it 'shows private items to the owner' do
    post login_path, params: { session: { email: owner.email, password: 'password' } }
    get user_path(owner)
    expect(response.body).to include('Private Movie')
  end

  context 'polymorphic activity and comment access control' do
    let!(:private_activity) { Activity.create!(user: owner, trackable: library_item, activity_type: 'added') }
    let!(:private_comment) { Comment.create!(user: owner, commentable: library_item, content: 'Secret comment') }

    it 'prevents visitor from liking an activity on a private item' do
      post toggle_like_path, params: { likeable_type: 'Activity', likeable_id: private_activity.id }
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['error']).to eq('Not authorized')
    end

    it 'prevents visitor from commenting on a private library item' do
      post comments_path, params: {
        comment: { content: 'Unauthorized', commentable_type: 'LibraryItem', commentable_id: library_item.id }
      }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Not authorized to comment on this item.')
    end

    it 'prevents visitor from liking a comment on a private item' do
      post toggle_like_path, params: { likeable_type: 'Comment', likeable_id: private_comment.id }
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['error']).to eq('Not authorized')
    end

    it 'allows owner to like their private activity' do
      post login_path, params: { session: { email: owner.email, password: 'password' } }
      post toggle_like_path, params: { likeable_type: 'Activity', likeable_id: private_activity.id }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['liked']).to be(true)
    end
  end
end
