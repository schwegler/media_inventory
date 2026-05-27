# frozen_string_literal: true

require 'rails_helper'
# rubocop:disable Metrics/BlockLength

RSpec.describe SessionsController, type: :controller do
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com', confirmed_at: Time.current) }

  describe 'GET #new' do
    it 'returns http success' do
      get :new
      expect(response).to have_http_status(:success)
      expect(response).to render_template('new')
    end
  end

  describe 'POST #create' do
    context 'with blank email' do
      it 'renders new template' do
        post :create, params: { session: { email: '' } }
        expect(response).to render_template('new')
      end

      it 'handles missing session params gracefully' do
        post :create, params: {}
        expect(response).to render_template('new')
      end
    end

    context 'with existing user' do
      it 'generates token and redirects to verify_otp' do
        expect(UserMailer).to receive_message_chain(:otp_email, :deliver_now)

        post :create, params: { session: { email: user.email } }

        user.reload
        expect(user.login_token).to be_present
        expect(session[:login_email]).to eq(user.email)
        expect(response).to redirect_to(verify_otp_path)
      end
    end

    context 'with new user' do
      it 'creates user, generates token, and redirects' do
        expect do
          post :create, params: { session: { email: 'new@example.com' } }
        end.to change(User, :count).by(1)

        new_user = User.last
        expect(new_user.email).to eq('new@example.com')
        expect(new_user.name).to eq('new')
        expect(new_user.login_token).to be_present
        expect(session[:login_email]).to eq('new@example.com')
        expect(flash[:info]).to include('Account created!')
        expect(response).to redirect_to(verify_otp_path)
      end
    end
  end

  describe 'GET #verify_otp' do
    context 'when email is present in session' do
      it 'renders the template' do
        session[:login_email] = 'test@example.com'
        get :verify_otp
        expect(assigns(:email)).to eq('test@example.com')
        expect(response).to render_template('verify_otp')
      end
    end

    context 'when logged in but no session login_email' do
      it 'uses current_user email and renders template' do
        # We need to simulate being logged in. We can set session[:user_id]
        session[:user_id] = user.id
        get :verify_otp
        expect(assigns(:email)).to eq(user.email)
        expect(response).to render_template('verify_otp')
      end
    end

    context 'when no email is available' do
      it 'redirects to root_url' do
        get :verify_otp
        expect(response).to redirect_to(root_url)
      end
    end
  end

  describe 'POST #verify_otp' do
    context 'with valid OTP' do
      before do
        user.generate_login_token
        post :verify_otp, params: { email: user.email, token: user.login_token }
      end

      it 'confirms user, clears tokens, logs in, and redirects' do
        user.reload
        expect(user.confirmed_at).to be_present
        expect(user.login_token).to be_nil
        expect(user.login_token_sent_at).to be_nil
        expect(session[:user_id]).to eq(user.id)
        expect(session[:login_email]).to be_nil
        expect(flash[:success]).to include('Email confirmed')
        expect(response).to redirect_to(user)
      end
    end

    context 'with invalid OTP' do
      before do
        user.generate_login_token
        post :verify_otp, params: { email: user.email, token: 'wrongtoken' }
      end

      it 'sets error flash and renders verify_otp' do
        expect(flash.now[:danger]).to include('Invalid or expired OTP')
        expect(assigns(:email)).to eq(user.email)
        expect(response).to render_template('verify_otp')
      end
    end

    context 'with expired OTP' do
      before do
        user.generate_login_token
        user.update!(login_token_sent_at: 1.hour.ago)
        post :verify_otp, params: { email: user.email, token: user.login_token }
      end

      it 'sets error flash and renders verify_otp' do
        expect(flash.now[:danger]).to include('Invalid or expired OTP')
        expect(response).to render_template('verify_otp')
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'logs out and redirects to root_url' do
      session[:user_id] = user.id
      delete :destroy
      expect(session[:user_id]).to be_nil
      expect(response).to redirect_to(root_url)
    end
  end
end
# rubocop:enable Metrics/BlockLength
