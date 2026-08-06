# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Landing Controller', type: :request do
  let(:regular_user) do
    User.create!(
      name: 'Regular User',
      email: 'regular@example.com',
      password: 'password',
      password_confirmation: 'password',
      username: 'regular'
    )
  end

  let(:admin_user) do
    User.create!(
      name: 'Admin User',
      email: 'admin@example.com',
      password: 'password',
      password_confirmation: 'password',
      username: 'admin',
      admin: true
    )
  end

  describe 'GET /db_status' do
    context 'when user is not logged in' do
      it 'redirects to root path with a not authorized alert' do
        get '/db_status'
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(flash[:alert]).to eq('Not authorized.')
      end
    end

    context 'when user is logged in but not an admin' do
      before do
        post login_path, params: { session: { email: regular_user.email, password: 'password' } }
      end

      it 'redirects to root path with a not authorized alert' do
        get '/db_status'
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(flash[:alert]).to eq('Not authorized.')
      end
    end

    context 'when user is logged in as an admin' do
      before do
        post login_path, params: { session: { email: admin_user.email, password: 'password' } }
      end

      it 'returns the database status in JSON format' do
        get '/db_status'
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('database_connected')
        expect(json_response).to have_key('activities_count')
        expect(json_response).to have_key('users_count')
        expect(json_response).to have_key('database_url')
      end
    end
  end
end
