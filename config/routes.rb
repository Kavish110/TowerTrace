Rails.application.routes.draw do
  resources :cases do
    resources :evidence_files, only: %i[create show]
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "cases#index"
end
