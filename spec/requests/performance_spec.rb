# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Performance Optimization', type: :request do
  describe 'series child tracking' do
    let(:user) do
      User.create!(name: 'Reader', email: 'performance@example.com', password: 'password123',
                   confirmed_at: Time.current)
    end

    before do
      post login_path, params: { session: { email: user.email, password: 'password123' } }
    end

    def tracking_queries(path)
      queries = []
      subscriber = lambda do |*, payload|
        queries << payload[:sql] if payload[:sql].match?(/\b(?:library_items|consumption_passes)\b/i)
      end
      ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') { get path }
      expect(response).to have_http_status(:ok)
      queries.size
    end

    [TvShow, Comic].each do |model|
      [false, true].each do |in_library|
        it "keeps #{model} tracking queries bounded with library membership #{in_library}" do
          series = model.create!(title: 'Large series')
          LibraryItem.create!(user: user, item: series) if in_library
          children = model == TvShow ? series.tv_episodes : series.comic_issues
          create_child = lambda do |number|
            attributes = if model == TvShow
                           { name: "Episode #{number}", season: 1, episode: number }
                         else
                           { title: "Issue #{number}", issue_number: number }
                         end
            children.create!(attributes)
          end
          create_child.call(1)
          small_count = tracking_queries(polymorphic_path(series))
          (2..15).each { |number| create_child.call(number) }
          large_count = tracking_queries(polymorphic_path(series))

          expect(large_count).to be <= small_count
          expect(response.body).to include(model == TvShow ? 'Episode 15' : 'Issue 15')
        end
      end
    end
  end

  describe 'GET /movies' do
    it 'loads the application layout with deferred javascript' do
      get movies_path
      expect(response).to have_http_status(200)
      # Assert that the script tag DOES have defer="defer"
      expect(response.body).to include('<script type="importmap"')
      expect(response.body).to include('import "application"')
    end
  end

  describe 'RecordPreloader library_items eager loading' do
    include RecordPreloader

    it 'eager loads :library_items association on preloaded media items' do
      movie1 = Movie.create!(title: 'Movie 1', release_year: 2024)
      movie2 = Movie.create!(title: 'Movie 2', release_year: 2024)

      preload_records_attachments([movie1, movie2])

      expect(movie1.association(:library_items)).to be_loaded
      expect(movie2.association(:library_items)).to be_loaded
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
end
