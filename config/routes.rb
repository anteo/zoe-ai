Rails.application.routes.draw do
  devise_for :users, skip: [ :registrations ], path: "", path_names: {
    sign_in: "login",
    sign_out: "logout",
    sign_up: "register"
  }, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks"
  }
  devise_scope :user do
    get "register", to: "devise/registrations#new", as: :new_user_registration
    post "register", to: "devise/registrations#create", as: :user_registration
  end
  get "up" => "rails/health#show", as: :rails_health_check

  root "chats#show"

  resources :mcp_servers, only: [ :index, :new, :create, :edit, :update, :destroy ] do
    member do
      patch :start
      patch :stop
    end
  end
  resource :profile, only: [ :show, :update ]
  resource :settings, only: [ :show, :update ]
  namespace :admin do
    resource :mission_control, only: :show
  end

  authenticate :user, lambda { |user| user.admin? } do
    mount MissionControl::Jobs::Engine => "/admin/mission_control/app", as: :mission_control_jobs
  end

  get "models/search", to: "models#search", as: :models_search

  resources :chats, only: [:show, :new, :destroy] do
    collection do
      get :history_list
    end

    member do
      get :history_detail
    end
  end
  resources :messages, only: [:create, :update, :destroy] do
    member do
      post :resend
    end
  end
  resources :characters, only: [:index, :new, :create, :edit, :update, :destroy] do
    collection do
      get :accept_share
    end
    post :select, on: :member
    get :section, on: :member
    get :share, on: :member
    post :deliver_share, on: :member
  end
end
