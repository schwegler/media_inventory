require 'rails_helper'

RSpec.describe "EditSuggestions", type: :request do
  let(:user) { User.create!(name: "Test User", email: "test@example.com", password: "password", username: "testuser") }
  let(:movie) { Movie.create!(title: "Test Movie", release_year: 2024) }

  before do
    post login_path, params: { session: { email: user.email, password: "password" } }
  end

  describe "GET /movies/:movie_id/edit_suggestions/new" do
    it "renders the new template" do
      get new_movie_edit_suggestion_path(movie)
      expect(response).to have_http_status(200)
    end
  end

  describe "POST /movies/:movie_id/edit_suggestions" do
    it "creates an edit suggestion" do
      expect {
        post movie_edit_suggestions_path(movie), params: { edit_suggestion: { proposed_changes: { title: "New Title" } } }
      }.to change(EditSuggestion, :count).by(1)
      
      expect(response).to redirect_to(movie_path(movie))
      expect(EditSuggestion.last.status).to eq("pending")
    end
  end
end
