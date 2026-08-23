# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sentinel Security Checks', type: :request do
  describe 'OmniAuth setup mastodon' do
    before do
      allow(Rails.env).to receive(:test?).and_return(false)
      strategy = double('strategy', request: double('req', params: {}), name: 'mastodon')
      allow_any_instance_of(ActionDispatch::Request).to receive(:env).and_wrap_original do |m, *args|
        env = m.call(*args)
        env['omniauth.strategy'] = strategy
        env
      end
    end

    it 'returns bad request without reflecting request parameters when server is missing' do
      get '/auth/mastodon/setup', params: { secret_param: 'super_secret' }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq('Mastodon server required.')
      expect(response.body).not_to include('super_secret')
      expect(response.body).not_to include('req.params')
    end
  end

  describe 'InventoryController logging' do
    let(:user) { User.create!(name: 'Test User', email: 'test@example.com', password: 'password', username: 'testuser') }

    before do
      post login_path, params: { session: { email: user.email, password: 'password' } }
    end

    it 'does not log raw params.inspect on creation' do
      expect(Rails.logger).not_to receive(:debug).with(a_string_matching(/DEBUG CREATE PARAMS/))

      post movies_path, params: { movie: { title: 'Test Movie', rating: 5, secret_token: 'sensitive123' } }
    end
  end
end
