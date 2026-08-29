Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :stk_pushes, only: [:create]
      resources :disbursements, only: [:create]
      resources :refunds, only: [:create]

      post "c2b/register_urls", to: "c2b#register_urls"
      post "c2b/simulate", to: "c2b#simulate"
    end
  end

  namespace :webhooks do
    post "mpesa/stk", to: "mpesa#receive", as: :mpesa_stk
    post "mpesa/c2b", to: "mpesa#receive", as: :mpesa_c2b
    post "mpesa/result", to: "mpesa#receive", as: :mpesa_result
    post "mpesa/timeout", to: "mpesa#receive", as: :mpesa_timeout
  end
end
