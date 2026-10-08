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
      expect(response.body).to include('Activity')
      expect(response.body).to include('Collection')
      expect(response.body).to include('Backlog')
      expect(response.body).to include('Likes')
      # Profile sections now use server-rendered navigation with readable URLs.
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('.library-profile-tabs a[aria-current="page"]').text).to eq('Overview')
      expect(document.at_css('.library-profile-tabs a[href$="tab=collection"]').text).to eq('Collection')
    end
  end
end
