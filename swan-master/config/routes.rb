Rails.application.routes.draw do
  resource :registration
  resolve("Registration") { [:registration] }
  resources :registrations
  resources :users
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  controller :sessions do
    get  'login' => :new
    post 'login' => :create
    delete 'logout' => :destroy
  end

  root 'registrations#show', as: 'index'
end
