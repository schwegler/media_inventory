# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Authentication', type: :request do
  let!(:user) do
    User.create!(
      name: 'Example User',
      email: 'user@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
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
    it 'logs the user in successfully with correct credentials' do
      post login_path, params: { session: { email: user.email, password: 'password123' } }
      expect(session[:user_id]).to eq(user.id)
      expect(response).to redirect_to(user)
    end
  end

  describe 'invalid login' do
    it 'renders the new session template with error' do
      post login_path, params: { session: { email: user.email, password: 'wrongpassword' } }
      expect(session[:user_id]).to be_nil
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Invalid email/password combination')
    end
  end

  describe 'logout' do
    before do
      post login_path, params: { session: { email: user.email, password: 'password123' } }
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
      initial_session_id = request.session.id

      post login_path, params: { session: { email: user.email, password: 'password123' } }

      expect(session[:user_id]).to eq(user.id)
      expect(request.session.id).not_to eq(initial_session_id)
    end
  end

  describe 'native client auto-login' do
    context 'when user agent indicates Hotwire Native app' do
      let(:headers) do
        { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) ' \
                          'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Hotwire Native' }
      end

      it 'automatically provisions a new Device User and logs in' do
        expect do
          get root_path, headers: headers
        end.to change(User, :count).by(1)

        new_user = User.last
        expect(new_user.name).to eq('Device User')
        expect(session[:user_id]).to eq(new_user.id)

        jar = ActionDispatch::TestRequest.create.cookie_jar
        jar[:device_user_id] = cookies[:device_user_id]
        expect(jar.signed[:device_user_id]).to eq(new_user.id)
      end

      it 'uses existing Device User from signed cookies if present' do
        guest = User.create!(
          name: 'Device User',
          password: 'guestpassword',
          password_confirmation: 'guestpassword',
          confirmed_at: Time.current
        )
        jar = ActionDispatch::TestRequest.create.cookie_jar
        jar.signed[:device_user_id] = guest.id
        cookies[:device_user_id] = jar[:device_user_id]

        expect do
          get root_path, headers: headers
        end.not_to change(User, :count)

        expect(session[:user_id]).to eq(guest.id)
      end
    end

    context 'when user agent indicates Tauri Desktop app' do
      let(:headers) { { 'User-Agent' => 'Mozilla/5.0 Tauri (MediaInventoryDesktop)' } }

      it 'automatically provisions a new Device User and logs in' do
        expect do
          get root_path, headers: headers
        end.to change(User, :count).by(1)

        new_user = User.last
        expect(new_user.name).to eq('Device User')
        expect(session[:user_id]).to eq(new_user.id)

        jar = ActionDispatch::TestRequest.create.cookie_jar
        jar[:device_user_id] = cookies[:device_user_id]
        expect(jar.signed[:device_user_id]).to eq(new_user.id)
      end
    end

    context 'when user agent is a standard web browser' do
      let(:headers) { { 'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36' } }

      it 'does not provision a Device User' do
        expect do
          get root_path, headers: headers
        end.not_to change(User, :count)

        expect(session[:user_id]).to be_nil
        expect(cookies[:device_user_id]).to be_nil
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
