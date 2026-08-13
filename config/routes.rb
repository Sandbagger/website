Rails.application.routes.draw do
  get "up", to: "rails/health#show", as: :rails_health_check
  get "/.well-known/site.standard.publication",
    to: "standard_site#publication",
    as: :standard_site_publication
  resources :feed, only: [:index], defaults: {format: "xml"}
  sitepress_pages
  sitepress_root
end
