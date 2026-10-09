# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'Admin game health', type: :request do
  it 'requires administrator access' do
    get admin_game_health_path
    expect(response).to redirect_to(root_path)
  end
  it 'shows failed artwork without exposing credentials' do
    admin = User.create!(name: 'Admin', email: 'admin@example.com', password: 'password123', admin: true)
    game = VideoGame.create!(title: 'Portal')
    CoverImport.create!(item: game, source_url: 'https://shared.akamai.steamstatic.com/header.jpg', state: 'failed',
                        failure_reason: 'HTTP 404')
    ApiConfiguration.create!(source_name: 'RAWG', media_type: 'VideoGame', is_active: true,
                             access_token: 'SECRET-DO-NOT-RENDER')
    post login_path, params: { session: { email: admin.email, password: 'password123' } }
    get admin_game_health_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Portal', 'HTTP 404', 'Game integration health')
    expect(response.body).not_to include('SECRET-DO-NOT-RENDER')
  end
end
