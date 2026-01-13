Rails.application.routes.draw do
  get "check", to: "check#index"

  get "map", to: "map#index"
  get "map/areas", to: "map#areas"

  get "up" => "rails/health#show", as: :rails_health_check
end
