Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users,
    path: "api/v1/auth",
    path_names: { registration: "sign_up" },
    controllers: {
      sessions: "api/v1/auth/sessions",
      registrations: "api/v1/auth/registrations",
      passwords: "api/v1/auth/passwords",
      confirmations: "api/v1/auth/confirmations"
    }

  namespace :api do
    namespace :v1 do
      get    "health",               to: "health#show"
      get    "users/me",             to: "users#me"
      patch  "users/me",             to: "users#update"
      patch  "users/me/email",       to: "users#update_email"
      patch  "users/me/password",    to: "users#update_password"
      delete "users/me",             to: "users#destroy"
      post   "subscriptions",        to: "subscriptions#create"
      get    "subscriptions/current", to: "subscriptions#current"
      delete "subscriptions/current", to: "subscriptions#cancel"
      post   "webhooks/stripe",      to: "webhooks#stripe"
    end
  end
end
