Rails.application.routes.draw do
  get "up", to: "rails/health#show", as: :rails_health_check
  resources :feed, only: [:index], defaults: {format: "xml"}
  sitepress_pages
  sitepress_root
end
