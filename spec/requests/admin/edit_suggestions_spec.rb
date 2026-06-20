# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::EditSuggestions', type: :request do
  let(:admin) do
    User.create!(name: 'Admin User', email: 'admin@example.com', password: 'password', username: 'admin', admin: true)
  end
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com', password: 'password', username: 'testuser') }
  let(:movie) { Movie.create!(title: 'Test Movie', release_year: 2024) }
  let(:edit_suggestion) do
    EditSuggestion.create!(suggestable: movie, user: user, proposed_changes: { 'title' => 'Approved Title' })
  end

  before do
    post login_path, params: { session: { email: admin.email, password: 'password' } }
  end

  describe 'POST /admin/edit_suggestions/:id/approve' do
    it 'approves the edit suggestion and updates the media item' do
      post approve_admin_edit_suggestion_path(edit_suggestion)

      edit_suggestion.reload
      movie.reload

      expect(edit_suggestion.status).to eq('approved')
      expect(movie.title).to eq('Approved Title')
      expect(Notification.last.action).to eq('approved_edit')
      expect(response).to redirect_to(admin_edit_suggestion_path(edit_suggestion))
    end
  end

  describe 'POST /admin/edit_suggestions/:id/reject' do
    it 'rejects the edit suggestion' do
      post reject_admin_edit_suggestion_path(edit_suggestion)

      edit_suggestion.reload
      movie.reload

      expect(edit_suggestion.status).to eq('rejected')
      expect(movie.title).to eq('Test Movie') # Unchanged
      expect(Notification.last.action).to eq('rejected_edit')
      expect(response).to redirect_to(admin_edit_suggestion_path(edit_suggestion))
    end
  end
end
