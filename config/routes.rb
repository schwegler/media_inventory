# frozen_string_literal: true

SampleApp::Application.routes.draw do
  resources :posts, only: %i[create destroy show]
  resources :notifications, only: %i[index] do
    collection do
      post :mark_as_read
    end
  end
  namespace :admin do
    resources :api_configurations
    resources :activities
    resources :albums do
      member do
        get :merge
        post :do_merge
        get :search_api
        post :update_from_api
      end
    end
    resources :books do
      member do
        get :merge
        post :do_merge
        get :search_api
        post :update_from_api
      end
    end
    resources :comics do
      member do
        get :merge
        post :do_merge
        get :search_api
        post :update_from_api
      end
    end
    resources :comic_issues
    resources :comments
    resources :edit_suggestions do
      member do
        post :approve
        post :reject
      end
    end
    resources :library_items
    resources :likes
    resources :mastodon_oauth_applications
    resources :movies do
      member do
        get :merge
        post :do_merge
        get :search_api
        post :update_from_api
      end
    end
    resources :relationships
    resources :tv_episodes
    resources :tv_shows do
      member do
        get :merge
        post :do_merge
        get :search_api
        post :update_from_api
      end
    end
    resources :users
    resources :video_games do
      member do
        get :merge
        post :do_merge
        get :search_api
        post :update_from_api
      end
    end

    root to: 'activities#index'
  end
  root 'landing#index'
  get 'test_bsky', to: 'landing#test_bsky'
  get '/search', to: 'search#index', as: 'search'
  get '/collections/:user_id', to: 'collections#show', as: 'collection'
  get    '/login',   to: 'sessions#new'
  post   '/login',   to: 'sessions#create'
  delete '/logout',  to: 'sessions#destroy'
  get    '/signup',  to: 'users#new'

  resources :users do
    member do
      get :following
      get :followers
    end
  end

  resources :relationships, only: %i[create destroy]

  resources :comics do
    resources :edit_suggestions, only: %i[new create]
  end
  resources :tv_shows do
    resources :edit_suggestions, only: %i[new create]
  end
  resources :tv_episodes, only: %i[show]
  resources :video_games do
    resources :edit_suggestions, only: %i[new create]
  end
  resources :movies do
    resources :edit_suggestions, only: %i[new create]
  end
  resources :albums do
    resources :edit_suggestions, only: %i[new create]
  end
  resources :books do
    resources :edit_suggestions, only: %i[new create]
  end

  get '/settings', to: 'settings#basic_info', as: 'settings'
  scope :settings, as: 'settings' do
    get 'basic_info', to: 'settings#basic_info'
    get 'notifications', to: 'settings#notifications'
    get 'account', to: 'settings#account'
    get 'import', to: 'settings#import'
    get 'social', to: 'settings#social'
    post 'import_letterboxd', to: 'settings#import_letterboxd'
  end

  patch '/settings/update_basic_info', to: 'settings#update_basic_info'
  patch '/settings/update_notifications', to: 'settings#update_notifications'
  patch '/settings/update_account', to: 'settings#update_account'
  patch '/settings/update_social', to: 'settings#update_social'
  delete '/settings/disconnect_mastodon', to: 'settings#disconnect_mastodon'
  delete '/settings/disconnect_bluesky', to: 'settings#disconnect_bluesky'
  delete '/settings/delete_account', to: 'settings#delete_account'

  get '/db_status', to: 'landing#db_status'
  get '/media/autocomplete', to: 'media#autocomplete'
  post '/media/copy', to: 'media#copy'
  post '/likes/toggle', to: 'likes#toggle', as: 'toggle_like'

  resources :comments, only: :create

  patch '/tv_episodes/:id/toggle_watched', to: 'tv_episodes#toggle_watched', as: 'toggle_watched_tv_episode'
  get '/tv_episodes/:id/toggle_watched', to: redirect { |params, _request|
    episode = TvEpisode.find_by(id: params[:id])
    episode ? "/tv_shows/#{episode.tv_show_id}" : '/tv_shows'
  }

  resources :comic_issues, only: %i[show]
  patch '/comic_issues/:id/toggle_read', to: 'comic_issues#toggle_read', as: 'toggle_read_comic_issue'
  get '/comic_issues/:id/toggle_read', to: redirect { |params, _request|
    issue = ComicIssue.find_by(id: params[:id])
    issue ? "/comics/#{issue.comic_id}" : '/comics'
  }

  # OmniAuth routes
  match '/auth/:provider/setup', to: 'omniauth_callbacks#setup', via: %i[get post]
  match '/auth/:provider/callback', to: 'omniauth_callbacks#mastodon', constraints: { provider: 'mastodon' },
                                    via: %i[get post]
  match '/auth/:provider/callback', to: 'omniauth_callbacks#atproto', constraints: { provider: 'atproto' },
                                    via: %i[get post]
  get '/auth/failure', to: 'omniauth_callbacks#failure'

  # Client metadata endpoint for Bluesky OAuth
  get '/client-metadata.json', to: 'client_metadata#show', as: :client_metadata

  # ActivityPub & WebFinger
  get '/.well-known/webfinger', to: 'webfinger#show'
  get '/users/:id/actor', to: 'activitypub#actor', as: 'activitypub_actor'
  get '/users/:id/outbox', to: 'activitypub#outbox', as: 'activitypub_outbox'
  post '/users/:id/inbox', to: 'activitypub#inbox', as: 'activitypub_inbox'
end
