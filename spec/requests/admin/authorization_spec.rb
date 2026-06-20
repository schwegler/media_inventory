# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Authorization', type: :request do
  let(:user) do
    User.create!(name: 'Normal User', email: 'normal@example.com', password: 'password', password_confirmation: 'password')
  end
  let(:admin) do
    User.create!(name: 'Admin User', email: 'admin@example.com', password: 'password', password_confirmation: 'password',
                 admin: true)
  end

  describe 'accessing admin paths' do
    context 'when not logged in' do
      it 'redirects to root with unauthorized' do
        get admin_root_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Not authorized.')
      end
    end

    context 'when logged in as normal user' do
      before do
        post login_path, params: { session: { email: user.email, password: 'password' } }
      end

      it 'redirects to root with unauthorized' do
        get admin_root_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Not authorized.')
      end
    end

    context 'when logged in as admin' do
      before do
        post login_path, params: { session: { email: admin.email, password: 'password' } }
      end

      it 'allows access' do
        get admin_root_path
        expect(response).to have_http_status(:success)
      end
    end
  end
end
