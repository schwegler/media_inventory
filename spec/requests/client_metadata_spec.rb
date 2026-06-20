# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ClientMetadata', type: :request do
  describe 'GET /client-metadata.json' do
    it 'returns http success' do
      get client_metadata_path
      expect(response).to have_http_status(:success)
    end
  end
end
