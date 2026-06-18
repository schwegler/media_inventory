# frozen_string_literal: true

SampleApp::Application.routes.draw do
  root 'landing#index'
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

  resources :comics
  resources :tv_shows
  resources :tv_episodes, only: %i[show]
  resources :video_games
  resources :movies
  resources :albums

  get '/settings', to: 'settings#basic_info', as: 'settings'
  scope :settings, as: 'settings' do
    get 'basic_info', to: 'settings#basic_info'
    get 'notifications', to: 'settings#notifications'
    get 'account', to: 'settings#account'
  end

  patch '/settings/update_basic_info', to: 'settings#update_basic_info'
  patch '/settings/update_notifications', to: 'settings#update_notifications'
  patch '/settings/update_account', to: 'settings#update_account'
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

  # OmniAuth routes
  match '/auth/:provider/setup', to: 'omniauth_callbacks#setup', via: [:get, :post]
  match '/auth/:provider/callback', to: 'omniauth_callbacks#mastodon', constraints: { provider: 'mastodon' }, via: [:get, :post]
  match '/auth/:provider/callback', to: 'omniauth_callbacks#atproto', constraints: { provider: 'atproto' }, via: [:get, :post]
  get '/auth/failure', to: 'omniauth_callbacks#failure'

  # Client metadata endpoint for Bluesky OAuth
  get '/client-metadata.json', to: 'client_metadata#show', as: :client_metadata

  # ActivityPub & WebFinger
  get '/.well-known/webfinger', to: 'webfinger#show'
  get '/users/:id/actor', to: 'activitypub#actor', as: 'activitypub_actor'
  get '/users/:id/outbox', to: 'activitypub#outbox', as: 'activitypub_outbox'
  post '/users/:id/inbox', to: 'activitypub#inbox', as: 'activitypub_inbox'
end
