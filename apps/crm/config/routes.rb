Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  root "dashboard#show"
  get "search" => "search#index", as: :search

  resources :leads do
    member do
      patch :verify
      patch :discard
      patch :qualify
      post :convert
    end
    resource :score, only: %i[edit update], controller: "lead_scores"
    resources :analyses, only: :create, controller: "lead_analyses" do
      member do
        patch :accept
        patch :reject
      end
    end
  end

  resources :companies
  resource :agent_control, only: :show, controller: "agent_control"
  resources :opportunities do
    patch :move, on: :member
  end
  resources :activities, only: %i[index create destroy] do
    patch :complete, on: :member
  end

  namespace :admin do
    resources :users, except: %i[show destroy]
    resources :service_rates, except: :show do
      patch :approve, on: :member
    end
    resources :commercial_thresholds, except: :show
    resources :audit_logs, only: :index
  end

  namespace :api do
    namespace :v1 do
      resources :lead_ingestions, only: :create
    end
  end

  # Meta webhooks (plan r2, 7.1). Off unless META_WEBHOOKS_ENABLED=true.
  get "webhooks/meta" => "webhooks/meta#verify", as: :meta_webhook
  post "webhooks/meta" => "webhooks/meta#receive"

  get "up" => "rails/health#show", as: :rails_health_check
end
