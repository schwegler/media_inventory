# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User pages', type: :request do
  let!(:user) do
    User.create!(name: 'Example User', email: 'user@example.com', password: 'password123',
                 password_confirmation: 'password123', username: 'example')
  end

  describe 'show' do
    it 'returns http success and contains accessible clipboard elements' do
      post login_path, params: { session: { email: user.email, password: 'password123' } }
      get user_path(user)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(user.name)
      expect(response.body).to include('data-controller="clipboard"')
      expect(response.body).to include('data-clipboard-target="button"')
    end

    it 'redirects to login when not logged in' do
      get user_path(user)
      expect(response).to redirect_to(login_path)
    end
  end
end
