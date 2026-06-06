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
  resources :wrestling_events
  resources :movies
  resources :albums
  get '/db_status', to: 'landing#db_status'
  get '/media/autocomplete', to: 'media#autocomplete'
end
