Rails.application.routes.draw do
  require "sidekiq/web"

  get "up" => "rails/health#show", as: :rails_health_check

  root "things#index"

  resources :things do
    collection do
      get "by_beacon/:ble_beacon_uuid", action: :by_beacon, as: :by_beacon
      post :bulk_print
      get :bulk_label_preview
    end

    member do
      delete "photos/:photo_id", to: "things#purge_photo", as: :photo
      delete :ar_anchor, to: "things#purge_ar_anchor"
      get :label_preview
      post :duplicate
      post :print
      patch :labelled, action: :update_labelled
    end
  end

  namespace :settings do
    root to: "site#show"
    resource :site, only: %i[show update], controller: "site"
    resource :scan_visits, only: %i[show], controller: "scan_visits"
    resources :printers do
      collection do
        get :cups_queues
      end
      member do
        post :test_connection
        post :test_print
      end
    end
    resources :unifi_controllers do
      member do
        post :test_connection
        post :import
      end
    end
    resources :unifi_devices, only: :update
    resources :zigbee2mqtt_bridges do
      member do
        post :test_connection
        post :import
      end
    end
    resources :zigbee2mqtt_devices, only: :update
  end

  get "login", to: "sessions#new"
  delete "logout", to: "sessions#destroy"
  post "login/local", to: "local_sessions#create", as: :local_login

  get "/auth/:provider/callback", to: "omniauth_callbacks#openid_connect"
  get "/auth/failure", to: "omniauth_callbacks#failure"

  mount Sidekiq::Web => "/sidekiq"

  get "/:key", to: "things#show", as: :short_thing, constraints: { key: /[a-z][a-z0-9]{7}/ }
end
