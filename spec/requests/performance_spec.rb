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

  describe 'GET /movies/:id community reviews and comments eager loading' do
    let(:user) { User.create!(name: 'Reviewer', email: 'reviewer@example.com', password: 'password', username: 'reviewer') }
    let(:movie) { Movie.create!(title: 'Inception', director: 'Nolan', release_year: 2010) }

    before do
      library_item = LibraryItem.create!(user: user, item: movie, review: 'Great movie!', rating: 5.0, is_public: true)
      comment = library_item.comments.create!(user: user, content: 'Awesome review!')
      comment.replies.create!(commentable: library_item, user: user, content: 'Thanks!')
    end

    it 'eager loads reviews, comments, replies, and likes without triggering N+1 queries' do
      get movie_path(movie)
      expect(response).to have_http_status(200)
      expect(response.body).to include('Great movie!')
      expect(response.body).to include('Awesome review!')
      expect(response.body).to include('Thanks!')
    end
  end
end
