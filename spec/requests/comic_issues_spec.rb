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
  it 'persists public review visibility and queues publishing an existing review' do
    user = User.create!(name: 'Reader', email: 'reader@example.com', password: 'password123',
                        confirmed_at: Time.current)
    LibraryItem.create!(user: user, item: comic)
    entry = LibraryItem.create!(user: user, item: comic_issue, review: 'Good issue', is_public: false)
    post login_path, params: { session: { email: user.email, password: 'password123' } }
    allow(SocialPostJob).to receive(:perform_later)

    patch toggle_read_comic_issue_path(comic_issue), params: { comic_issue: { is_public: '1' } }

    expect(entry.reload).to be_is_public
    expect(SocialPostJob).to have_received(:perform_later).with(entry, 'reviewed')
  end
end
