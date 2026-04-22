require 'rails_helper'

RSpec.describe "Collections", type: :request do
  describe "GET /show" do
    let!(:user) { User.create!(name: "Test", email: "test@example.com") }

    it "returns http success" do
      get "/collections/#{user.id}"
      expect(response).to have_http_status(:success)
    end
  end

end
