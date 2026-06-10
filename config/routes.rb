Rails.application.routes.draw do
  require "sidekiq/web"

  get "up" => "rails/health#show", as: :rails_health_check

  root "things#index"

  resources :things do
    member do
      delete "photos/:photo_id", to: "things#purge_photo", as: :photo
    end
  end

  namespace :settings do
    root to: "site#show"
    resource :site, only: %i[show update], controller: "site"
    resources :printers
  end

  get "login", to: "sessions#new"
  delete "logout", to: "sessions#destroy"
  post "login/local", to: "local_sessions#create", as: :local_login

  get "/auth/:provider/callback", to: "omniauth_callbacks#openid_connect"
  get "/auth/failure", to: "omniauth_callbacks#failure"

  mount Sidekiq::Web => "/sidekiq"
end
