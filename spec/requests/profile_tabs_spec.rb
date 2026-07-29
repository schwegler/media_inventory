# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile Tabs', type: :request do
  let(:user) { User.create!(name: 'Tab User', email: 'tabs@example.com', password: 'password', confirmed_at: Time.current) }

  before do
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  describe 'GET /users/:id' do
    it 'renders the profile with tabs and correct accessibility attributes' do
      get user_path(user)
      expect(response.body).to include('Activity')
      expect(response.body).to include('Collection')
      expect(response.body).to include('Backlog')
      expect(response.body).to include('Likes')
      expect(response.body).to include('data-controller="tabs"')
      expect(response.body).to include('role="tablist"')
      expect(response.body).to include('aria-label="Profile Sections"')
    end
  end
end
