# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comments', type: :request do
  let!(:user) do
    User.create!(name: 'Test', email: "test#{SecureRandom.hex(4)}@test.com", password: 'password',
                 password_confirmation: 'password')
  end
  let!(:album) { Album.create!(title: 'Test Album') }

  describe 'POST /comments' do
    before do
      post login_path, params: { session: { email: user.email, password: 'password' } }
    end

    it 'creates a comment when logged in' do
      expect do
        post comments_path, params: { comment: { content: 'Nice!', commentable_type: 'Album', commentable_id: album.id } }
      end.to change(Comment, :count).by(1)
    end

    it 'creates a reply comment when parent_id is valid' do
      parent = Comment.create!(user: user, commentable: album, content: 'Parent comment')
      expect do
        post comments_path, params: {
          comment: { content: 'Reply comment', commentable_type: 'Album', commentable_id: album.id, parent_id: parent.id }
        }
      end.to change(Comment, :count).by(1)
      reply = Comment.last
      expect(reply.parent_id).to eq(parent.id)
    end

    it 'rejects comment creation when parent_id belongs to a different commentable' do
      other_album = Album.create!(title: 'Other Album')
      parent = Comment.create!(user: user, commentable: other_album, content: 'Other comment')
      expect do
        post comments_path, params: {
          comment: { content: 'Invalid reply', commentable_type: 'Album', commentable_id: album.id, parent_id: parent.id }
        }
      end.not_to change(Comment, :count)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Invalid parent comment.')
    end

    it 'rejects comment creation when parent_id does not exist' do
      expect do
        post comments_path, params: {
          comment: { content: 'Invalid reply', commentable_type: 'Album', commentable_id: album.id, parent_id: 999_999 }
        }
      end.not_to change(Comment, :count)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Invalid parent comment.')
    end
  end
end
