# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'EditSuggestions', type: :request do
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com', password: 'password', username: 'testuser') }
  let(:movie) { Movie.create!(title: 'Test Movie', release_year: 2024) }

  before do
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  describe 'GET /movies/:movie_id/edit_suggestions/new' do
    it 'renders the new template' do
      get new_movie_edit_suggestion_path(movie)
      expect(response).to have_http_status(200)
    end
  end

  describe 'POST /movies/:movie_id/edit_suggestions' do
    it 'creates an edit suggestion' do
      expect do
        post movie_edit_suggestions_path(movie), params: { edit_suggestion: { proposed_changes: { title: 'New Title' } } }
      end.to change(EditSuggestion, :count).by(1)

      expect(response).to redirect_to(movie_path(movie))
      expect(EditSuggestion.last.status).to eq('pending')
    end
  end

  describe 'authorization and invalid resource checks' do
    let(:other_user) do
      User.create!(name: 'Other', email: 'other@example.com', password: 'password', username: 'otheruser')
    end
    let(:private_post) { Post.create!(content: 'Private Post', user: other_user) }

    it 'redirects to root when accessing edit suggestion for non-existent resource' do
      get new_movie_edit_suggestion_path(movie_id: 999_999)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Resource not found or unauthorized')
    end
  end

  it 'offers labeled provider facts and queues their corrections without allowing members to approve them' do
    movie.update!(metadata_details: { 'Runtime' => 90, 'Languages' => ['English'], 'related_steam_dlc_ids' => [123] })
    get new_movie_edit_suggestion_path(movie)
    html = Nokogiri::HTML(response.body)
    runtime = html.at_css('input[name="edit_suggestion[proposed_changes][metadata_details][Runtime]"]')
    expect(runtime['type']).to eq('number')
    expect(response.body).to include('Runtime (minutes)', 'One value per line.')
    expect(response.body).not_to include('[metadata_details][related_steam_dlc_ids]')
    post movie_edit_suggestions_path(movie), params: { edit_suggestion: { proposed_changes: {
      metadata_details: { 'Runtime' => '100', 'Languages' => "English\nFrench" }
    } } }
    suggestion = EditSuggestion.last
    expect(suggestion.status).to eq('pending')
    expect(movie.reload.metadata_details['Runtime']).to eq(90)
    post approve_admin_edit_suggestion_path(suggestion)
    expect(suggestion.reload.status).to eq('pending')
    expect(movie.reload.metadata_details['Runtime']).to eq(90)
  end
end
