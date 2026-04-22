# frozen_string_literal: true

require 'rails_helper'
# rubocop:disable Metrics/BlockLength

RSpec.describe 'Authentication', type: :request do
  let!(:user) do
    User.create!(name: 'Example User', email: 'user@example.com', confirmed_at: Time.current)
  end

  describe 'login page' do
    before { get login_path }

    it 'returns http success' do
      expect(response).to have_http_status(:success)
    end

    it 'contains Log in text' do
      expect(response.body).to include('Log in')
    end
  end

  describe 'valid login' do
    it 'creates a token and redirects to OTP verification for existing user' do
      post login_path, params: { session: { email: user.email } }
      expect(response).to redirect_to(verify_otp_path)
      user.reload
      expect(user.login_token).to be_present
    end

    it 'logs the user in successfully after providing valid OTP' do
      post login_path, params: { session: { email: user.email } }
      user.reload
      post verify_otp_path, params: { email: user.email, token: user.login_token }

      expect(session[:user_id]).to eq(user.id)
      expect(response).to redirect_to(user)
    end
  end

  describe 'invalid login' do
    before do
      post login_path, params: { session: { email: user.email } }
      user.reload
      post verify_otp_path, params: { email: user.email, token: 'invalid' }
    end

    it 'renders the verify_otp template' do
      expect(response.body).to include('Verify OTP')
    end

    it 'displays an error message' do
      expect(response.body).to include('Invalid or expired OTP')
    end
  end

  describe 'logout' do
    before do
      post login_path, params: { session: { email: user.email } }
      user.reload
      post verify_otp_path, params: { email: user.email, token: user.login_token }
      delete logout_path
    end

    it 'redirects to root' do
      expect(response).to redirect_to(root_url)
    end

    it 'logs the user out' do
      expect(session[:user_id]).to be_nil
    end
  end

  describe 'session fixation' do
    it 'rotates the session id after successful login' do
      get login_path
      post login_path, params: { session: { email: user.email } }
      initial_session_id = request.session.id

      user.reload
      post verify_otp_path, params: { email: user.email, token: user.login_token }

      expect(session[:user_id]).to eq(user.id)
      expect(request.session.id).not_to eq(initial_session_id)
    end
  end
end
# rubocop:enable Metrics/BlockLength
