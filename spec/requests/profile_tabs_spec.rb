# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile Tabs', type: :request do
  let(:user) { User.create!(name: 'Tab User', email: 'tabs@example.com', password: 'password', confirmed_at: Time.current) }

  before do
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  describe 'GET /users/:id' do
    it 'renders the profile with tabs' do
      get user_path(user)
      expect(response.body).to include('Activity')
      expect(response.body).to include('Collection')
      expect(response.body).to include('Backlog')
      expect(response.body).to include('Likes')
      # Profile sections now use server-rendered navigation with readable URLs.
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('.library-profile-tabs a[aria-current="page"]').text).to eq('Overview')
      expect(document.at_css('.library-profile-tabs a[href$="tab=collection"]').text).to eq('Collection')
    end

    it 'loads data conditionally for each profile tab without querying unrendered feed/likes data on collection tab' do
      movie = Movie.create!(title: 'Tab Movie')
      LibraryItem.create!(user: user, item: movie, is_collected: true, is_public: true)
      Post.create!(user: user, content: 'Test post on profile')

      # Navigating to collection tab should render collection and not issue queries for posts or likes
      get user_path(user, tab: 'collection')
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Tab Movie')
      expect(response.body).not_to include('Test post on profile')

      # Navigating to posts tab should render posts
      get user_path(user, tab: 'posts')
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Test post on profile')

      # Navigating to likes tab should render successfully
      get user_path(user, tab: 'likes')
      expect(response).to have_http_status(:ok)
    end

    it 'calculates library mix and backlog counts using a single aggregated SQL query on library_items' do
      movie = Movie.create!(title: 'Collected Movie')
      book = Book.create!(title: 'Backlog Book')
      game = VideoGame.create!(title: 'Collected and Backlog Game')

      LibraryItem.create!(user: user, item: movie, is_collected: true, is_public: true)
      LibraryItem.create!(user: user, item: book, in_backlog: true, is_public: true)
      LibraryItem.create!(user: user, item: game, is_collected: true, in_backlog: true, is_public: true)

      queries = []
      subscriber = lambda do |*, payload|
        queries << payload[:sql] if payload[:sql].include?('is_collected') && payload[:sql].include?('in_backlog')
      end

      ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
        get user_path(user)
      end

      expect(response).to have_http_status(:ok)
      # Exactly 1 GROUP BY query on library_items for preparing profile library statistics
      expect(queries.size).to eq(1)

      controller = @controller
      expect(controller.instance_variable_get(:@library_mix)).to eq({ 'Movie' => 1, 'VideoGame' => 1 })
      expect(controller.instance_variable_get(:@backlog_count)).to eq(2)
      expect(controller.instance_variable_get(:@collection_count)).to eq(2)
    end
  end
end
