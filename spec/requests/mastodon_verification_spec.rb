# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Site owner Mastodon verification', type: :request do
  let(:verification_selector) { 'head link[rel="me"][href="https://mastodon.social/@schwegler"]' }

  it 'includes one verification link in the homepage HTML without JavaScript' do
    get root_path

    expect(response).to have_http_status(:success)
    expect(Nokogiri::HTML(response.body).css(verification_selector).size).to eq(1)
  end

  it 'does not attribute another user profile or shelf to the site owner' do
    user = User.create!(name: 'Another Curator', username: 'another_curator', email: 'curator@example.test',
                        password: 'password123', password_confirmation: 'password123', confirmed_at: Time.current)

    [user_path(user), shelf_path(user.username), login_path].each do |path|
      get path

      expect(response).to have_http_status(:success)
      expect(Nokogiri::HTML(response.body).css(verification_selector)).to be_empty
    end
  end
end
