# frozen_string_literal: true

SampleApp::Application.routes.draw do
  root 'users#index'
  get '/collections/:user_id', to: 'collections#show', as: 'collection'
  get    '/login',   to: 'sessions#new'
  post   '/login',   to: 'sessions#create'
  get    '/verify_otp', to: 'sessions#verify_otp'
  post   '/verify_otp', to: 'sessions#verify_otp'
  delete '/logout',  to: 'sessions#destroy'
  resources :users

  resources :comics
  resources :tv_shows
  resources :wrestling_events
  resources :movies
  resources :albums
end
