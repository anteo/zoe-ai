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

  resource :profile, only: [ :show, :update ]
  resource :settings, only: [ :show, :update ] do
    get "section/:section" => "settings#section", as: :section
  end

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
    post :select, on: :member
    get :section, on: :member
  end
end
