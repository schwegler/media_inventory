# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users index', type: :request do # rubocop:disable Metrics/BlockLength
  let!(:user) do
    User.create!(name: 'Example User', email: 'user@example.com')
  end

  describe 'GET /users' do # rubocop:disable Metrics/BlockLength
    context 'when not logged in' do
      before { get users_path }

      it 'redirects to login path' do
        expect(response).to redirect_to(login_path)
      end

      it 'sets a flash message' do
        expect(flash[:danger]).to eq('Please log in.')
      end
    end

    context 'when logged in as non-admin' do
      before do
        post login_path, params: { session: { email: user.email } }
        user.reload
        post verify_otp_path, params: { email: user.email, token: user.login_token }
        get users_path
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'displays the user list' do
        expect(response.body).to include(user.name)
      end

      it 'does not show delete links' do
        expect(response.body).not_to include('data-confirm="You sure?"')
      end
    end

    context 'when logged in as admin' do
      let!(:admin) do
        User.create!(name: 'Admin User', email: 'admin@example.com', admin: true)
      end

      before do
        post login_path, params: { session: { email: admin.email } }
        admin.reload
        post verify_otp_path, params: { email: admin.email, token: admin.login_token }
        get users_path
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'shows delete links' do
        expect(response.body).to include('delete')
      end
    end

    context 'pagination' do
      before do
        30.times do |n|
          User.create!(name: "User #{n}", email: "user-#{n}@example.com")
        end
        post login_path, params: { session: { email: user.email } }
        user.reload
        post verify_otp_path, params: { email: user.email, token: user.login_token }
        get users_path
      end

      it 'shows pagination links' do
        expect(response.body).to include('pagination')
      end

      it 'lists each user' do
        User.paginate(page: 1).each do |u|
          expect(response.body).to include(u.name)
        end
      end
    end
  end
end
