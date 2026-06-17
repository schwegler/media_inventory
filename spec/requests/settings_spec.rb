# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settings', type: :request do
  let(:user) { User.create(name: 'Test User', email: 'test@example.com', password: 'password', confirmed_at: Time.current) }

  before do
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  describe 'GET /settings/basic_info' do
    it 'returns http success' do
      get settings_basic_info_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /settings/update_basic_info' do
    it 'updates the user' do
      patch settings_update_basic_info_path, params: { user: { username: 'new_username', bio: 'New Bio' } }
      user.reload
      expect(user.username).to eq('new_username')
      expect(user.bio).to eq('New Bio')
      expect(response).to redirect_to(settings_basic_info_path)
    end
  end

  describe 'PATCH /settings/update_notifications' do
    it 'updates notification preferences' do
      patch settings_update_notifications_path, params: { user: { notify_email_likes: false, notify_push_follows: false } }
      user.reload
      expect(user.notify_email_likes).to be false
      expect(user.notify_push_follows).to be false
      expect(response).to redirect_to(settings_notifications_path)
    end
  end

  describe 'DELETE /settings/delete_account' do
    it 'deletes the user' do
      expect do
        delete settings_delete_account_path
      end.to change(User, :count).by(-1)
      expect(response).to redirect_to(root_url)
    end
  end
end
