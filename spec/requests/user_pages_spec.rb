# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User pages', type: :request do
  let!(:user) do
    User.create!(name: 'Example User', email: 'user@example.com')
  end

  describe 'show' do
    it 'returns http success' do
      post login_path, params: { session: { email: user.email } }
      user.reload
      post verify_otp_path, params: { email: user.email, token: user.login_token }
      user.reload
      post verify_otp_path, params: { email: user.email, token: user.login_token }
      get user_path(user)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(user.name)
    end

    it 'redirects to login when not logged in' do
      get user_path(user)
      expect(response).to redirect_to(login_path)
    end
  end
end
