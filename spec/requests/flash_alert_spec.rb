# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Flash Alerts UX', type: :request do
  describe 'rendering flash messages' do
    it 'includes accessible dismissible close buttons' do
      post login_path, params: { session: { email: 'wrong@example.com', password: 'wrongpassword' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('class="alert alert-danger alert-dismissible"')
      expect(response.body).to include('class="alert-close-btn"')
      expect(response.body).to include('aria-label="Dismiss alert"')
      expect(response.body).to include('data-action="click->flash#dismiss"')
      expect(response.body).to include('class="alert-text"')
    end
  end
end
