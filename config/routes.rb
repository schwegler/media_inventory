# frozen_string_literal: true

SampleApp::Application.routes.draw do
  root 'landing#index'
  get '/collections/:user_id', to: 'collections#show', as: 'collection'
  get    '/login',   to: 'sessions#new'
  post   '/login',   to: 'sessions#create'
  delete '/logout',  to: 'sessions#destroy'
  get    '/signup',  to: 'users#new'
  resources :users

  resources :comics
  resources :tv_shows
  resources :tv_episodes, only: %i[show]
  resources :video_games
  resources :movies
  resources :albums
  get '/db_status', to: 'landing#db_status'
  get '/media/autocomplete', to: 'media#autocomplete'
  post '/media/copy', to: 'media#copy'
  post '/likes/toggle', to: 'likes#toggle', as: 'toggle_like'

  resources :comments, only: :create
  patch '/tv_episodes/:id/toggle_watched', to: 'tv_episodes#toggle_watched', as: 'toggle_watched_tv_episode'
  get '/tv_episodes/:id/toggle_watched', to: redirect { |params, request|
    episode = TvEpisode.find_by(id: params[:id])
    episode ? "/tv_shows/#{episode.tv_show_id}" : "/tv_shows"
  }

  # Bluesky custom session creation
  post '/sessions/bsky_login', to: 'sessions#bsky_create'

  # ActivityPub & WebFinger
  get '/.well-known/webfinger', to: 'webfinger#show'
  get '/users/:id/actor', to: 'activitypub#actor', as: 'activitypub_actor'
  get '/users/:id/outbox', to: 'activitypub#outbox', as: 'activitypub_outbox'
  post '/users/:id/inbox', to: 'activitypub#inbox', as: 'activitypub_inbox'
end
