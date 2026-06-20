# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ComicIssues', type: :request do
  let!(:comic) { Comic.create!(title: 'Test Comic') }
  let!(:comic_issue) { ComicIssue.create!(comic: comic, issue_number: '1', title: 'Test Issue') }

  describe 'GET /comic_issues/:id' do
    it 'returns http success' do
      get comic_issue_path(comic_issue)
      expect(response).to have_http_status(:success)
    end
  end
end
