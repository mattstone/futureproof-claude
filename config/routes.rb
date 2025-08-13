Rails.application.routes.draw do
  namespace :users do
    resources :verifications, only: [:new, :create] do
      collection do
        post :resend
      end
    end
  end
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions'
  }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Admin routes
  namespace :admin do
    resources :dashboard, only: [:index]
    resources :users
    resources :mortgages
    resources :applications do
      collection do
        post :search
      end
      member do
        post :create_message
        patch :send_message
      end
    end
    resources :contracts do
      collection do
        post :search
      end
      member do
        post :create_message
        patch :send_message
      end
    end
    resources :terms_of_uses, except: [:destroy] do
      member do
        patch :activate
      end
      collection do
        post :preview
      end
    end
    resources :privacy_policies, except: [:destroy] do
      member do
        patch :activate
      end
      collection do
        post :preview
      end
    end
    resources :terms_and_conditions, except: [:destroy] do
      member do
        patch :activate
      end
      collection do
        post :preview
      end
    end
    resources :email_templates, except: [:destroy] do
      member do
        patch :activate
        patch :deactivate
        get :preview
        post :test_email
      end
      collection do
        post :preview_ajax
      end
    end
    root "dashboard#index"
  end

  # API routes
  namespace :api do
    get 'mortgage_estimate', to: 'calculations#mortgage_estimate'
    get 'monthly_income', to: 'calculations#monthly_income'
    get 'check_email', to: 'calculations#check_email'
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Legal pages
  get "privacy-policy", to: "pages#privacy_policy"
  get "terms-of-use", to: "pages#terms_of_use", as: :terms_of_use
  get "terms-and-conditions", to: "pages#terms_and_conditions", as: :terms_and_conditions
  
  # Apply page
  get "apply", to: "pages#apply"
  
  # User dashboard
  get "dashboard", to: "dashboard#index"
  get "start-application", to: "dashboard#start_application"

  # Application routes
  resources :applications, except: [:index, :destroy] do
    member do
      get :income_and_loan
      patch :update_income_and_loan
      get :summary
      patch :submit
      get :congratulations
      get :messages
      post :reply_to_message
    end
  end

  # Contract routes
  resources :contracts, only: [:show] do
    member do
      get :messages
      post :reply_to_message
    end
  end

  # Dashboard Application routes
  namespace :dashboard do
    resources :applications, except: [:index, :destroy], path: 'app' do
      member do
        get :income_and_loan
        patch :update_income_and_loan
        get :summary
        patch :submit
        get :congratulations
      end
    end
  end

  # Defines the root path route ("/")
  root "pages#index"
end
