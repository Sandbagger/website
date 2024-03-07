Rails.application.routes.draw do
  # resources :feed, only: [:index]
  get "hit/handle", to: "hit#handle"
  sitepress_pages
  sitepress_root
end
