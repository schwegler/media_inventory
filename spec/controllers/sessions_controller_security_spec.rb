
require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  describe "POST #create" do
    let!(:user) { User.create!(name: "Test User", email: "test@example.com", password: "password", bsky_handle: "test.bsky.social", bsky_app_password: nil, bsky_password: nil) }

    it "does NOT allow login with missing password even if user has nil password in DB" do
      post :create, params: { session: { bsky_handle: "test.bsky.social" } }
      expect(session[:user_id]).to be_nil
      expect(flash[:danger]).to eq('Invalid Bluesky Handle/App Password combination.')
    end

    it "does not allow login if password is provided as empty string" do
      post :create, params: { session: { bsky_handle: "test.bsky.social", bsky_password: "" } }
      expect(session[:user_id]).to be_nil
      expect(flash[:danger]).to eq('Invalid Bluesky Handle/App Password combination.')
    end
  end
end
