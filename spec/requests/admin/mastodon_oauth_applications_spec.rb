# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::MastodonOauthApplications', type: :request do
  let(:admin) do
    User.create!(name: 'Admin User', email: "admin_#{SecureRandom.hex(4)}@example.com", password: 'password',
                 password_confirmation: 'password', admin: true)
  end

  before do
    post login_path, params: { session: { email: admin.email, password: 'password' } }
  end

  describe 'GET /admin/mastodon_oauth_applications' do
    it 'returns http success' do
      get admin_mastodon_oauth_applications_path
      expect(response).to have_http_status(:success)
    end
  end
end
