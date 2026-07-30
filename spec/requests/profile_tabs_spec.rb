# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile and Auth Tabs', type: :request do
  let(:user) { User.create!(name: 'Tab User', email: 'tabs@example.com', password: 'password', confirmed_at: Time.current) }

  describe 'GET /users/:id' do
    before do
      post login_path, params: { session: { email: user.email, password: 'password' } }
    end

    it 'renders the profile with tabs and keydown event bindings' do
      get user_path(user)
      expect(response.body).to include('Activity')
      expect(response.body).to include('Collection')
      expect(response.body).to include('Backlog')
      expect(response.body).to include('Likes')
      expect(response.body).to include('data-controller="tabs"')
      expect(response.body).to include('keydown->tabs#keydown')
    end
  end

  describe 'GET /login' do
    it 'renders the login tabs with keydown event bindings' do
      get login_path
      expect(response.body).to include('data-controller="tabs"')
      expect(response.body).to include('keydown->tabs#keydown')
    end
  end

  describe 'GET /signup' do
    it 'renders the signup tabs with keydown event bindings' do
      get signup_path
      expect(response.body).to include('data-controller="tabs"')
      expect(response.body).to include('keydown->tabs#keydown')
    end
  end
end
