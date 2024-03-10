Rails.application.routes.draw do
  resources :feed, only: [:index],  defaults: { format: 'xml' }
  get "hit/handle", to: "hit#handle"
  sitepress_pages
  sitepress_root
end
