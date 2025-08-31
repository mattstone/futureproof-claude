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
    resources :lenders do
      member do
        get :available_wholesale_funders
      end
      resources :wholesale_funders, controller: 'lender_wholesale_funders', except: [:index, :show] do
        member do
          patch :toggle_active
        end
        collection do
          post :add_wholesale_funder
          delete :remove_wholesale_funder
          post :toggle_pool
        end
      end
      resources :funder_pools, controller: 'lender_funder_pools', except: [:index, :show] do
        collection do
          get :available_pools
          post :add_pool
        end
        member do
          patch :toggle_active
        end
      end
      # Singleton clause resource - one clause per lender
      resource :clause, controller: 'lender_clauses', except: [:show]
    end
    resources :wholesale_funders do
      collection do
        post :search
      end
      resources :funder_pools, except: [:index]
    end
    
    # Direct access to all funder pools
    resources :funder_pools, only: [:index]
    resources :dashboard, only: [:index]
    resources :users
    resources :mortgages do
      resources :lenders, controller: 'mortgage_lenders', except: [:index, :show, :new, :edit] do
        collection do
          get :available_lenders
          post :add_lender
        end
        member do
          patch :toggle_active
        end
      end
      resources :mortgage_contracts do
        member do
          patch :activate
          patch :publish
        end
        collection do
          post :preview
        end
        resources :contract_clauses, only: [:create, :destroy] do
          collection do
            get :available_clauses
          end
        end
      end
    end
    resources :applications do
      collection do
        post :search
      end
      member do
        post :create_message
        patch :send_message
        patch :advance_to_processing
        patch :update_checklist_item
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
    
    # Calculator
    resources :calculators, only: [:index] do
      collection do
        post :calculate
      end
    end
    
    # Error notification testing (production only, futureproof admins only)
    if Rails.env.production?
      resource :error_test, only: [:show] do
        collection do
          post :test_error
          post :test_database_error
          post :test_view_error
        end
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
  
  # Games (authenticated users only)
  get "arcade", to: "games#arcade"
  get "honky-pong", to: "games#honky_pong"
  get "honky-pong-simple", to: "games#honky_pong_simple"
  get "honky-pong-minimal", to: "games#honky_pong_minimal"
  get "simple-honky-pong", to: "games#simple_honky_pong"
  get "lace-invaders", to: "games#lace_invaders"
  get "hackman", to: "games#hackman"
  get "defendher", to: "games#defendher"
  get "hemorrhoids", to: "games#hemorrhoids", as: :hemorrhoids

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
      patch :mark_all_messages_as_read
    end
  end

  # Contract routes
  resources :contracts, only: [:show] do
    member do
      get :messages
      post :reply_to_message
      patch :mark_all_messages_as_read
    end
  end

  # Message routes
  resources :application_messages, only: [] do
    member do
      patch :mark_as_read
    end
  end

  resources :contract_messages, only: [] do
    member do
      patch :mark_as_read
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
