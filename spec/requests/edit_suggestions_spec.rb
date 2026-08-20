# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'EditSuggestions', type: :request do
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com', password: 'password', username: 'testuser') }
  let(:movie) { Movie.create!(title: 'Test Movie', release_year: 2024) }
  let(:book) { Book.create!(title: 'Test Book', author: 'Author Name') }

  before do
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  describe 'GET /movies/:movie_id/edit_suggestions/new' do
    it 'renders the new template' do
      get new_movie_edit_suggestion_path(movie)
      expect(response).to have_http_status(200)
    end

    it 'redirects when resource is not found' do
      get new_movie_edit_suggestion_path(movie_id: 999_999)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Resource not found')
    end

    it 'redirects when user is not authorized' do
      allow_any_instance_of(ApplicationController).to receive(:can_access?).and_return(false)
      get new_movie_edit_suggestion_path(movie)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Not authorized')
    end
  end

  describe 'POST /movies/:movie_id/edit_suggestions' do
    it 'creates an edit suggestion for a movie' do
      expect do
        post movie_edit_suggestions_path(movie), params: { edit_suggestion: { proposed_changes: { title: 'New Title' } } }
      end.to change(EditSuggestion, :count).by(1)

      expect(response).to redirect_to(movie_path(movie))
      expect(EditSuggestion.last.status).to eq('pending')
    end
  end

  describe 'POST /books/:book_id/edit_suggestions' do
    it 'creates an edit suggestion for a book' do
      expect do
        post book_edit_suggestions_path(book),
             params: { edit_suggestion: { proposed_changes: { title: 'New Book Title' } } }
      end.to change(EditSuggestion, :count).by(1)

      expect(response).to redirect_to(book_path(book))
      expect(EditSuggestion.last.status).to eq('pending')
    end
  end
end
