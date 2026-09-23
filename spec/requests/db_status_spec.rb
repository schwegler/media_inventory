# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Database Status Endpoint Authorization', type: :request do
  let(:regular_user) do
    User.create!(name: 'Regular User', email: 'regular@example.com', password: 'password', username: 'regular_user')
  end
  let(:admin_user) do
    User.create!(name: 'Admin User', email: 'admin@example.com', password: 'password', username: 'admin_user', admin: true)
  end

  context 'when unauthenticated' do
    it 'redirects to root path with an authorization error' do
      get db_status_path
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include('Not authorized')
    end
  end

  context 'when logged in as regular user' do
    before do
      post login_path, params: { session: { email: regular_user.email, password: 'password' } }
    end

    it 'redirects to root path with an authorization error' do
      get db_status_path
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include('Not authorized')
    end
  end

  context 'when logged in as admin user' do
    before do
      post login_path, params: { session: { email: admin_user.email, password: 'password' } }
    end

    it 'allows access and returns JSON status' do
      get db_status_path
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('database_connected')
      expect(json).to have_key('activities_count')
      expect(json).to have_key('users_count')
    end
  end
end
