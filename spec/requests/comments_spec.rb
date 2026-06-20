# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comments', type: :request do
  let!(:user) do
    User.create!(name: 'Test', email: "test_\#{SecureRandom.hex(4)}@test.com", password: 'password',
                 password_confirmation: 'password')
  end
  let!(:album) { Album.create!(title: 'Test Album') }

  describe 'POST /comments' do
    it 'creates a comment when logged in' do
      post login_path, params: { session: { email: user.email, password: 'password' } }
      expect do
        post comments_path, params: { comment: { content: 'Nice!', commentable_type: 'Album', commentable_id: album.id } }
      end.to change(Comment, :count).by(1)
    end
  end
end
