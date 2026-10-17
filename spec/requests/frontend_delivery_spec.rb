# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Selective frontend delivery', type: :request do
  it 'does not preload route-only controllers and marks the snapshot viewer' do
    get root_path
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('body')['data-viewer-id']).to eq('guest')
    preloads = page.css('link[rel="modulepreload"]').map { |link| link['href'] }
    route_controllers = %w[favorite_shelf_controller thumbnail_fetcher_controller game_status_controller]
    route_controllers.each { |name| expect(preloads.join).not_to include(name) }
    user = User.create!(name: 'Snapshot owner', email: 'snapshot@example.com', password: 'password',
                        confirmed_at: Time.current)
    post login_path, params: { session: { email: user.email, password: 'password' } }
    get root_path
    expect(Nokogiri::HTML(response.body).at_css('body')['data-viewer-id']).to eq(user.id.to_s)
    expect(response.headers['Cache-Control']).to include('private', 'no-store')
  end
end
