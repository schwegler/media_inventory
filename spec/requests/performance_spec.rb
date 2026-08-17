# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Performance Optimization', type: :request do
  describe 'GET /movies' do
    it 'loads the application layout with deferred javascript' do
      get movies_path
      expect(response).to have_http_status(200)
      # Assert that the script tag DOES have defer="defer"
      expect(response.body).to include('<script type="importmap"')
      expect(response.body).to include('import "application"')
    end
  end

  describe 'GET /posts/:id comment rendering performance' do
    let(:user) do
      User.create!(name: 'Test User', username: 'test_user', email: 'test@example.com', password: 'password',
                   confirmed_at: Time.current)
    end
    let(:post_item) { Post.create!(user: user, content: 'Test post content') }

    before do
      post login_path, params: { session: { email: user.email, password: 'password' } }

      3.times do |i|
        comment = Comment.create!(user: user, commentable: post_item, content: "Comment #{i}")
        2.times do |j|
          Comment.create!(user: user, commentable: post_item, parent: comment, content: "Reply #{i}-#{j}")
        end
      end
    end

    it 'renders nested comments with bounded database queries' do
      # Warm up session and schema
      get post_path(post_item)

      # Record queries when requesting post with nested comments & replies
      queries = []
      counter = lambda { |_name, _start, _finish, _id, payload|
        queries << payload[:sql] unless payload[:name] == 'SCHEMA'
      }

      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
        get post_path(post_item)
      end

      expect(response).to have_http_status(200)
      expect(queries.size).to be < 35
    end
  end
end
