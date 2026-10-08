# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin command center', type: :request do
  let(:admin) { User.create!(name: 'Operations', email: 'ops@example.com', password: 'password', admin: true) }
  let(:movie) { Movie.create!(title: 'A catalog title', release_year: 2024) }

  def login
    post login_path, params: { session: { email: admin.email, password: 'password' } }
  end

  it 'protects overview and global search from anonymous visitors' do
    [admin_root_path, admin_search_path(q: 'title')].each do |path|
      get path
      expect(response).to redirect_to(root_path)
    end
  end

  it 'protects new routes and mutation actions from non-administrators' do
    admin.update!(admin: false)
    login
    [admin_root_path, admin_search_path(q: 'title'), merge_admin_movie_path(movie)].each do |path|
      get path
      expect(response).to redirect_to(root_path)
    end
    post do_merge_admin_movie_path(movie), params: { target_id: movie.id }
    expect(response).to redirect_to(root_path)
    expect(Movie.exists?(movie.id)).to be true
  end

  context 'as an administrator' do
    before { login }

    it 'renders an intentional empty overview and every navigation group' do
      ApiConfiguration.create!(is_active: true)
      get admin_root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Command Center', 'All caught up', 'Media health', 'Background operations',
                                       'Incomplete configuration')
      Admin::CommandCenterHelper::NAVIGATION.each_value do |links|
        links.each_value { |label| expect(response.body).to include(label.gsub('&', '&amp;')) }
      end
    end

    it 'renders populated overview with actionable links and human activity' do
      suggestion = EditSuggestion.create!(user: admin, suggestable: movie, proposed_changes: { title: 'A new title' })
      LibraryItem.create!(user: admin, item: movie, is_collected: true)
      get admin_root_path
      expect(response.body).to include('A catalog title', 'added movie', admin_edit_suggestion_path(suggestion))
      expect(response.body).to include('health=missing_artwork', 'health=missing_id')
    end

    it 'filters missing artwork while retaining title search and pagination' do
      movie
      Movie.create!(title: 'An illustrated title', thumbnail_url: 'https://example.com/poster.jpg')
      get admin_movies_path(health: 'missing_artwork', search: 'catalog')
      expect(response.body).to include('A catalog title')
      expect(response.body).not_to include('An illustrated title')
    end

    it 'uses bounded search with distinct media and user groups' do
      movie
      admin.update!(name: 'Catalog manager')
      get admin_search_path(q: 'catalog')
      expect(response.body).to include('A catalog title', 'Catalog manager', 'Movies', 'Users')
      expect(response).to have_http_status(:ok)
    end

    it 'escapes wildcard searches and requires two characters' do
      movie
      get admin_search_path(q: '%_')
      expect(response.body).to include('No results')
      get admin_search_path(q: 'a')
      expect(response.body).to include('Enter at least two characters')
    end

    it 'renders CRUD and metadata views for populated media' do
      [admin_movie_path(movie), edit_admin_movie_path(movie), new_admin_movie_path,
       merge_admin_movie_path(movie)].each do |path|
        get path
        expect(response).to have_http_status(:ok)
      end
      expect(response.body).to include('data-turbo-confirm', 'Merge and delete source')
      allow(MediaSearchService).to receive(:call).and_return([{ title: 'Provider title', api_id: '45', author: 'Writer',
                                                                external_url: 'https://itunes.apple.com/item/45' }])
      get search_api_admin_movie_path(movie)
      expect(response.body).to include('Fill missing metadata', 'Review the match before applying it', 'itunes.apple.com')
    end

    it 'renders parent-filtered episode and issue indexes' do
      show = TvShow.create!(title: 'A show')
      episode = TvEpisode.create!(tv_show: show, name: 'Pilot', season: 1, episode: 1)
      comic = Comic.create!(title: 'A comic')
      issue = ComicIssue.create!(comic: comic, title: 'Origins', issue_number: 1)
      [admin_tv_show_path(show), admin_tv_episode_path(episode), admin_comic_path(comic), admin_comic_issue_path(issue),
       admin_tv_episodes_path(tv_show_id: show.id), admin_comic_issues_path(comic_id: comic.id)].each do |path|
        get path
        expect(response).to have_http_status(:ok)
      end
    end

    it 'masks credentials on show, index, forms, and search without overwriting blank replacements' do
      admin.update_columns(bsky_access_token: 'stored-bsky-secret', private_key: 'stored-private-key')
      config = ApiConfiguration.create!(source_name: 'TMDB', media_type: 'Movie', access_token: 'stored-api-secret')
      oauth = MastodonOauthApplication.create!(server: 'https://social.example.com', client_id: 'client',
                                               client_secret: 'stored-client-secret')
      [admin_user_path(admin), edit_admin_user_path(admin), admin_api_configurations_path,
       admin_api_configuration_path(config), edit_admin_api_configuration_path(config),
       admin_mastodon_oauth_application_path(oauth), edit_admin_mastodon_oauth_application_path(oauth),
       admin_search_path(q: 'stored')].each do |path|
        get path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('stored-bsky-secret', 'stored-private-key', 'stored-api-secret',
                                             'stored-client-secret')
      end
      patch admin_api_configuration_path(config), params: { api_configuration: { access_token: '', base_url: 'https://example.com' } }
      expect(config.reload.access_token).to eq('stored-api-secret')
      patch admin_api_configuration_path(config), params: { api_configuration: { access_token: 'replacement' } }
      expect(config.reload.access_token).to eq('replacement')
      patch admin_api_configuration_path(config),
            params: { api_configuration: { clear_credentials: ['access_token'] } }
      expect(config.reload.access_token).to be_nil
    end

    it 'preserves destructive CRUD confirmation and deletes only when posted' do
      get admin_movie_path(movie)
      expect(response.body).to include('data-turbo-confirm', 'This cannot be undone')
      delete admin_movie_path(movie)
      expect(Movie.exists?(movie.id)).to be false
      expect(response).to redirect_to(admin_movies_path)
    end
  end
end
