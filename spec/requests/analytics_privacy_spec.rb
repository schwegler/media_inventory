# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analytics privacy boundary', type: :request do
  def expect_no_google_collection
    document = Nokogiri::HTML(response.body)
    expect(document.css('script[src], iframe[src]').map { |node| node['src'] }.join(' '))
      .not_to match(/googletagmanager|google-analytics/)
    expect(document.css('script').map(&:text).join(' ')).not_to match(/gtag\s*\(/)
  end

  it 'does not initialize analytics on login or signup pages, including query strings' do
    [login_path, signup_path].each do |path|
      get path, params: { email: 'private@example.test', q: 'private search' }
      expect(response).to have_http_status(:success)
      expect_no_google_collection
    end
  end

  it 'does not initialize analytics after a failed login submission' do
    post login_path, params: { session: { email: 'private@example.test', password: 'invalid' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect_no_google_collection
  end

  it 'does not initialize analytics on authenticated account pages' do
    user = User.create!(name: 'Analytics Test', email: 'analytics-private@example.test',
                        password: 'password123', password_confirmation: 'password123', confirmed_at: Time.current)
    post login_path, params: { session: { email: user.email, password: 'password123' } }
    expect(session[:user_id]).to eq(user.id)
    get settings_account_path
    expect(response).to have_http_status(:success)
    expect_no_google_collection
  end
end
