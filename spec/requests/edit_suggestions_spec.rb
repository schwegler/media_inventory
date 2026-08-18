# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'EditSuggestions', type: :request do
  let(:user) do
    User.create!(name: 'Alice', email: 'alice@example.com', password: 'password', confirmed_at: Time.current)
  end
  let(:movie) { Movie.create!(title: 'Inception') }

  before do
    post login_path, params: { email: user.email, password: 'password' }
  end

  describe 'GET /movies/:movie_id/edit_suggestions/new' do
    context 'when movie exists and is accessible' do
      it 'renders new suggestion form successfully' do
        get new_movie_edit_suggestion_path(movie)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when movie does not exist' do
      it 'redirects safely to root path with an alert' do
        get new_movie_edit_suggestion_path(movie_id: 999_999)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(flash[:alert]).to eq('Resource not found or not authorized')
      end
    end
  end

  describe 'POST /movies/:movie_id/edit_suggestions' do
    context 'when movie exists and is accessible' do
      it 'creates an edit suggestion' do
        expect do
          post movie_edit_suggestions_path(movie),
               params: { edit_suggestion: { proposed_changes: { title: 'Inception 2' } } }
        end.to change(EditSuggestion, :count).by(1)

        expect(response).to redirect_to(movie_path(movie))
      end
    end

    context 'when movie does not exist' do
      it 'redirects safely without creating a suggestion' do
        expect do
          post movie_edit_suggestions_path(movie_id: 999_999),
               params: { edit_suggestion: { proposed_changes: { title: 'Ghost' } } }
        end.not_to change(EditSuggestion, :count)

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(flash[:alert]).to eq('Resource not found or not authorized')
      end
    end
  end
end
