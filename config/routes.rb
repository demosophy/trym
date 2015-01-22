require 'sidekiq/web'

Rails.application.routes.draw do
  
  resources :invite_requests, only: [:new, :create]

  resources :transaction_data_requests
  resources :financial_institutions, only: :index

  resources :account_details, only: [:new, :create, :edit, :update]
  resources :merchants, only: :index

  resources :charges do
    resources :stop_orders, only: [:new, :create, :show, :edit, :destroy]
  end

  resources :stop_orders, only: :index
  resources :verifications, only: [:new, :create], defaults: {format: 'js'}
  resources :contact_preferences, only: :update, defaults: {format: 'js'}

  devise_for :users

  authenticated :user do
    devise_scope :user do
      root to: "charges#index", :as => "my-charges"
    end
  end

  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  get 'static_pages/home'
  get 'static_pages/about'

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'static_pages#home'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
