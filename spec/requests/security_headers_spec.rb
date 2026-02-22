# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Security Headers', type: :request do
  describe 'GET /' do
    it 'sets the Content-Security-Policy header' do
      get root_path
      expect(response.headers['Content-Security-Policy']).to be_present
    end

    it "includes default-src 'self'" do
      get root_path
      csp = response.headers['Content-Security-Policy']
      expect(csp).to include("default-src 'self'")
      expect(csp).not_to include("default-src 'self' https:")
    end

    it 'includes a nonce for scripts' do
      get root_path
      csp = response.headers['Content-Security-Policy']
      expect(csp).to match(%r{script-src 'self' 'nonce-[a-zA-Z0-9+/=]+'})
    end
  end
end
