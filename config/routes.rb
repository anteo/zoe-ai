Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "chats#show"

  resources :chats, only: [:show, :new, :destroy]
  resources :messages, only: [:create, :update, :destroy] do
    member do
      post :resend
    end
  end

  post "select_character", to: "characters#select", as: :select_character
end
