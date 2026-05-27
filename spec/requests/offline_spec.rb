# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Offline Assets', type: :request do
  describe 'GET /service-worker.js' do
    it 'returns the service worker file' do
      get '/service-worker.js'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('media-inventory-cache-v1')
    end
  end

  describe 'GET /offline.html' do
    it 'returns the offline fallback page' do
      get '/offline.html'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('You are Offline')
      expect(response.body).to include('Add a Movie')
    end
  end
end
