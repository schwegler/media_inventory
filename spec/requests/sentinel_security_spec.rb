# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sentinel Security Safeguards', type: :request do
  let!(:user) do
    User.create!(
      name: 'Sentinel User',
      email: 'sentinel@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      username: 'sentinel_user'
    )
  end

  describe 'OmniAuth Mastodon setup parameter reflection' do
    let(:strategy) do
      double('strategy', request: double('req', params: { 'malicious_param' => 'leak_value' }), name: 'mastodon')
    end

    before do
      # Allow entering OmniAuthCallbacksController#setup by overriding Rails.env.test? check
      allow(Rails.env).to receive(:test?).and_return(false)
      # Stub MastodonAppRegistration to prevent external API calls
      allow(MastodonAppRegistration).to receive(:register).and_return(nil)
    end

    it 'fails cleanly without reflecting request parameters or keys in the error body' do
      get '/auth/mastodon/setup', env: { 'omniauth.strategy' => strategy }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to include('Mastodon server required.')
      expect(response.body).not_to include('req.params:')
      expect(response.body).not_to include('malicious_param')
      expect(response.body).not_to include('leak_value')
    end
  end

  describe 'InventoryController sensitive parameter logging' do
    before do
      post login_path, params: { session: { email: user.email, password: 'password123' } }
    end

    it 'does not log debug parameters during resource creation' do
      expect(Rails.logger).not_to receive(:debug).with(/DEBUG CREATE PARAMS/)

      post movies_path, params: { movie: { title: 'Security Audited Movie', release_year: 2026 } }
      expect(response).to redirect_to(Movie.last)
    end
  end
end
