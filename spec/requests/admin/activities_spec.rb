# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Activities', type: :request do
  let(:admin) { User.create!(name: 'Admin User', email: "admin_#{SecureRandom.hex(4)}@example.com", password: 'password', password_confirmation: 'password', admin: true) }

  before do
    post login_path, params: { session: { email: admin.email, password: 'password' } }
  end

  describe 'GET /admin/activities' do
    it 'returns http success' do
      get admin_activities_path
      expect(response).to have_http_status(:success)
    end
  end
end
