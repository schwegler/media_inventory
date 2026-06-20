# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Search', type: :request do
  describe 'GET /search' do
    it 'returns http success' do
      get search_path, params: { q: 'test' }
      expect(response).to have_http_status(:success)
    end
  end
end
