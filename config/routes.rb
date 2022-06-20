Rails.application.routes.draw do
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'

  devise_scope :user do
    # Redirests signing out users back to sign-in
    get "users", to: "devise/sessions#new"
  end

  # change default /user/action URLs for devise
  devise_for :users, path: '', path_names: { sign_in: 'signin', sign_out: 'signout', password: 'iforgot', confirmation: 'verification', unlock: 'unlock', registration: '', sign_up: 'signup' }

  #  get 'pages/index'
  #  get 'pages/welcome'
  #  get 'pages/about'

  match '/about',   to: 'pages#about',  via: 'get'
  match '/welcome', to: 'pages#welcome', via: 'get'

  resources :posts

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"

 root 'pages#index'

end
