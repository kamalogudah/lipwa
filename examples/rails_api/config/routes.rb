Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :stk_pushes, only: [:create]
      resources :disbursements, only: [:create]
      resources :refunds, only: [:create]

      post "c2b/register_urls", to: "c2b#register_urls"
      post "c2b/simulate", to: "c2b#simulate"
      post "jenga/transfers", to: "jenga#transfer"
      get "jenga/balance", to: "jenga#balance"
      get "jenga/statement", to: "jenga#statement"
      post "jenga/forex", to: "jenga#forex"
      post "jenga/disbursements", to: "jenga#disburse"
    end
  end

  namespace :webhooks do
    post "mpesa/stk", to: "mpesa#receive", as: :mpesa_stk
    post "mpesa/c2b", to: "mpesa#receive", as: :mpesa_c2b
    post "mpesa/result", to: "mpesa#receive", as: :mpesa_result
    post "mpesa/timeout", to: "mpesa#receive", as: :mpesa_timeout
    post "jenga", to: "jenga#receive", as: :jenga
  end
end
