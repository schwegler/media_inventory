# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users destroy', type: :request do
  let!(:user) do
    User.create!(name: 'Example User', email: 'user@example.com')
  end
  let!(:other_user) do
    User.create!(name: 'Other User', email: 'other@example.com')
  end
  let!(:admin) do
    User.create!(name: 'Admin User', email: 'admin@example.com', admin: true)
  end

  context 'as non-logged-in user' do
    it 'redirects to login path' do
      delete user_path(user)
      expect(response).to redirect_to(login_path)
    end

    it 'does not delete the user' do
      expect do
        delete user_path(user)
      end.not_to change(User, :count)
    end
  end

  context 'as non-admin user' do
    before do
      post login_path, params: { session: { email: user.email } }
        user.reload
        post verify_otp_path, params: { email: user.email, token: user.login_token }
    end

    it 'redirects to the root url' do
      delete user_path(user)
      expect(response).to redirect_to(root_url)
    end

    it 'does not delete the user' do
      expect do
        delete user_path(user)
      end.not_to change(User, :count)
    end
  end

  context 'as admin user' do
    before do
      post login_path, params: { session: { email: admin.email } }
        admin.reload
        post verify_otp_path, params: { email: admin.email, token: admin.login_token }
    end

    it 'deletes the user' do
      expect do
        delete user_path(user)
      end.to change(User, :count).by(-1)
    end

    it 'redirects to users index' do
      delete user_path(user)
      expect(response).to redirect_to(users_url)
    end
  end
end
