Rails.application.routes.draw do
  resources :feed, only: [:index], defaults: {format: "xml"}
  sitepress_pages
  sitepress_root
end
