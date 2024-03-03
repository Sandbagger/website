Rails.application.routes.draw do
  get 'hit/handle', to: 'hit#handle'
  sitepress_pages
  sitepress_root
end
