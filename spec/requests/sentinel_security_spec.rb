# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sentinel Security Fixes', type: :request do
  describe 'OmniAuth Mastodon setup' do
    it 'returns clean 400 error message without reflecting parameters when mastodon_server is blank' do
      allow(Rails.env).to receive(:test?).and_return(false)

      req_mock = double('request', params: { 'secret_param' => 'extremely_sensitive_token' })
      strategy_mock = double('strategy', name: 'mastodon', request: req_mock)

      # We can set the env before making the post request
      post '/auth/mastodon/setup', params: { secret_param: 'extremely_sensitive_token' }, headers: {
        'omniauth.strategy' => strategy_mock
      }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq('Mastodon server required.')
      expect(response.body).not_to include('secret_param')
      expect(response.body).not_to include('extremely_sensitive_token')
      expect(response.body).not_to include('inspect')
    end
  end

  describe 'Inventory Controller logging' do
    let!(:user) do
      User.create!(name: 'Test Log User', email: "loguser_#{SecureRandom.hex(4)}@test.com", password: 'password',
                   password_confirmation: 'password')
    end

    it 'does not log params.inspect when creating inventory items' do
      post login_path, params: { session: { email: user.email, password: 'password' } }

      # Set up expectation on Rails logger not to receive params.inspect
      expect(Rails.logger).not_to receive(:debug).with(/DEBUG CREATE PARAMS/)

      post movies_path, params: { movie: { title: 'Safe Movie', is_collected: '1' } }
      expect(response).to redirect_to(Movie.last)
    end
  end
end
