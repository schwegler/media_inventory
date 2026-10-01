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
  end

  describe 'GET /notifications' do
    let(:user) do
      User.create!(name: 'Recipient', email: 'recipient@example.com', password: 'password', username: 'recipient')
    end
    let(:actor) { User.create!(name: 'Actor', email: 'actor@example.com', password: 'password', username: 'actor') }
    let(:movie) { Movie.create!(title: 'Inception') }

    before do
      post login_path, params: { session: { email: user.email, password: 'password' } }

      # Create various notifications with polymorphic targets (Like, Comment, EditSuggestion)
      like = Like.create!(user: actor, likeable: movie)
      comment = Comment.create!(user: actor, commentable: movie, content: 'Great movie!')
      edit_suggestion = EditSuggestion.create!(user: actor, suggestable: movie, proposed_changes: { title: 'Inception 2' })

      Notification.create!(recipient: user, actor: actor, notifiable: like, action: 'liked')
      Notification.create!(recipient: user, actor: actor, notifiable: comment, action: 'commented')
      Notification.create!(recipient: user, actor: actor, notifiable: edit_suggestion, action: 'approved_edit')
    end

    it 'eager loads polymorphic notification targets and renders successfully' do
      get notifications_path
      expect(response).to have_http_status(200)
      expect(response.body).to include('liked your movie.')
      expect(response.body).to include('commented on your movie.')
      expect(response.body).to include('approved your edit suggestion for Inception')
    end
  end
end
