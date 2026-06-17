# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile Tabs', type: :request do
  let(:user) { User.create!(name: 'Tab User', email: 'tabs@example.com', password: 'password', confirmed_at: Time.current) }

  before do
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  describe 'GET /users/:id' do
    it 'renders the profile with tabs' do
      get user_path(user)
      expect(response.body).to include('Posts')
      expect(response.body).to include('Media')
      expect(response.body).to include('Likes')
      expect(response.body).to include('data-controller="tabs"')
    end
  end
end
