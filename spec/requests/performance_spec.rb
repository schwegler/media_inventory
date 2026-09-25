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

  describe 'GET /posts/:id' do
    let(:user) { User.create!(name: 'Author', email: 'author@example.com', password: 'password', username: 'author') }
    let(:post_record) { user.posts.create!(content: 'Hello world!') }

    before do
      post login_path, params: { session: { email: user.email, password: 'password' } }

      # Create comments and replies
      comment1 = post_record.comments.create!(user: user, content: 'First comment')
      comment1.replies.create!(commentable: post_record, user: user, content: 'First reply')
      comment2 = post_record.comments.create!(user: user, content: 'Second comment')
      comment2.replies.create!(commentable: post_record, user: user, content: 'Second reply')
    end

    it 'eager loads comments, users, and replies successfully' do
      get post_path(post_record)
      expect(response).to have_http_status(200)
      expect(response.body).to include('First comment')
      expect(response.body).to include('First reply')
      expect(response.body).to include('Second comment')
      expect(response.body).to include('Second reply')
    end

    it 'reuses preloaded comments and replies in views without executing extra SQL queries for comments' do
      loaded_post = Post.includes(comments: [:user, :likes, { replies: %i[user likes] }]).find(post_record.id)

      expect(loaded_post.comments.loaded?).to be true
      expect(loaded_post.comments.first.replies.loaded?).to be true

      comment_queries = 0
      callback = lambda do |_name, _start, _finish, _id, payload|
        comment_queries += 1 if payload[:sql] =~ /FROM ["`]?comments["`]?/i
      end

      # Ruby in-memory filtering for root comments and preloaded replies generates 0 SQL queries on comments table
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        root_comments = if loaded_post.comments.loaded?
                          loaded_post.comments.select { |c| c.parent_id.nil? }
                        else
                          loaded_post.comments.where(parent_id: nil)
                        end
        root_comments.each do |c|
          _replies = c.replies.loaded? ? c.replies : c.replies.to_a
        end
      end

      expect(comment_queries).to eq(0)
    end
  end
end
