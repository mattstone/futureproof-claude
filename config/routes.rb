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
    sessions: 'users/sessions',
    omniauth_callbacks: 'users/omniauth_callbacks'
  }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Global jurisdiction setting (accessible from anywhere)
  post 'set_jurisdiction', to: 'admin/base#set_jurisdiction'

  # Admin routes
  namespace :admin do
    post 'set_jurisdiction', to: 'base#set_jurisdiction'
    
    # Dashboard
    get 'dashboard', to: 'dashboard#index'
    get 'dashboard/webhooks', to: 'dashboard#webhooks'
    post 'dashboard/retry_webhook/:id', to: 'dashboard#retry_webhook', as: 'retry_webhook'
    patch 'dashboard/toggle_webhook/:id', to: 'dashboard#toggle_webhook', as: 'toggle_webhook'
    get 'dashboard/applications', to: 'dashboard#applications'
    get 'dashboard/payments', to: 'dashboard#payments'
    
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
      
      # Broker commission rates
      resources :broker_commission_rates do
        member do
          patch :toggle_active
        end
      end
    end
    
    resources :brokers do
      member do
        patch :toggle_active
        post :assign_lender
        delete :remove_lender
      end
    end
    
    resources :wholesale_funders do
      collection do
        post :search
        get :by_jurisdiction
      end
      resources :funder_pools, except: [:index]
      resources :contracts, controller: 'wholesale_funder_contracts', only: [:index, :new, :create, :edit, :update, :destroy]
    end
    
    # Direct access to all funder pools
    resources :funder_pools, only: [:index]
    get 'business', to: 'old_dashboard#business'
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
      resources :documents, controller: 'application_documents', only: [:index, :create, :destroy] do
        member do
          patch :verify
          patch :reject
          post :auto_verify
        end
        collection do
          post :request_all
        end
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
        post :send_test
      end
      collection do
        post :preview_ajax
      end
    end
    
    resources :email_workflows do
      member do
        patch :toggle_active
        get :preview
        post :duplicate
      end
      collection do
        get :add_step
        get :templates
        get :email_templates_content
        post :bulk_create
        get :node_properties
      end
    end
    
    # New v2 business process workflows (visual interface)
    resources :business_process_workflows do
      member do
        post :add_trigger
        delete :remove_trigger
        patch :update_trigger
      end
    end
    
    # Form-based workflow interface (alternative to visual)
    resources :workflow_forms, only: [:index, :show] do
      member do
        get :new_trigger
        post :create_trigger
        get :edit_trigger
        patch :update_trigger
        delete :destroy_trigger
      end
    end

    # Agent Action Dashboard
    resources :agent_dashboard, only: [:index, :show] do
      member do
        patch :override
      end
      collection do
        get :timeline
      end
    end

    # Broker Management
    resources :brokers, except: [:destroy] do
      member do
        patch :toggle_active
      end
      resources :lenders, controller: 'broker_lenders', only: [] do
        member do
          patch :toggle_active
        end
        collection do
          get :available_lenders
          post :add_lender
          delete :remove_lender
        end
      end
    end

    # Agent Lifecycle Management (NEW - replaces complex workflow builders)
    resources :agent_lifecycle, only: [:index, :show, :edit, :update] do
      member do
        get :add_stage
        get :edit_stage
        post :update_stage
        delete :delete_stage
      end
    end

    # Calculator
    resources :calculators, only: [:index] do
      collection do
        post :calculate
      end
    end

    # CoreLogic API Test
    resources :core_logic_test, only: [:index] do
      collection do
        get :search
        get :property_details
        get :autocomplete
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
    
    get 'old', to: 'old_dashboard#index', as: 'old_dashboard'
    root "admin_dashboard_v2#dashboard_v2"
  end

  # API routes
  namespace :api do
    get 'mortgage_estimate', to: 'calculations#mortgage_estimate'
    get 'monthly_income', to: 'calculations#monthly_income'
    get 'check_email', to: 'calculations#check_email'

    # Quote API - supports multiple calculation models
    get 'quotes', to: 'quotes#show'
    get 'quotes/compare', to: 'quotes#compare'
    get 'quotes/models', to: 'quotes#models'

    # Region-aware quote (uses CalculationEngine)
    get 'quotes/regional', to: 'quotes#regional'
    get 'regions', to: 'quotes#regions'

    # AI Chat API
    post 'chat', to: 'chat#create'
    post 'chat/guest', to: 'chat#guest_message'
    get 'chat/conversations', to: 'chat#conversations'
    get 'chat/conversations/:id/messages', to: 'chat#messages'
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Region-scoped customer-facing routes (AU, NZ, UK)
  # Root (/) defaults to US; /au, /nz, /uk for other regions
  scope "/:region", constraints: { region: /au|nz|uk/ } do
    get "privacy-policy", to: "pages#privacy_policy", as: :regional_privacy_policy
    get "terms-of-use", to: "pages#terms_of_use", as: :regional_terms_of_use
    get "terms-and-conditions", to: "pages#terms_and_conditions", as: :regional_terms_and_conditions
    get "apply", to: "pages#apply", as: :regional_apply
    get "get-started", to: "pages#get_started", as: :regional_get_started
    get "/", to: "pages#get_started", as: :regional_root

    # Customer Support (24/7 AI chat)
    get 'support', to: 'support#chat', as: 'support_chat'
    post 'support/send_message', to: 'support#send_message', as: 'support_send_message'
    delete 'support/clear', to: 'support#clear', as: 'support_clear'

    # Borrower Portal (authenticated borrowers only)
    get 'borrower_portal/:application_id', to: 'borrower_portal#dashboard', as: 'borrower_portal'
    get 'borrower_portal/:application_id/annuity_schedule', to: 'borrower_portal#annuity_schedule', as: 'borrower_portal_annuity_schedule'
    get 'borrower_portal/:application_id/loan_details', to: 'borrower_portal#loan_details', as: 'borrower_portal_loan_details'
    get 'borrower_portal/:application_id/property_details', to: 'borrower_portal#property_details', as: 'borrower_portal_property_details'
    get 'borrower_portal/:application_id/documents', to: 'borrower_portal#documents', as: 'borrower_portal_documents'

    # Key Facts Sheet (legal document)
    get 'key_facts_sheet/:application_id', to: 'legal_documents#key_facts_sheet', as: 'key_facts_sheet'

    # Loan Activation (authenticated borrowers - approved applications only)
    get 'loan_activation/:application_id', to: 'loan_activation#show', as: 'loan_activation'
    post 'loan_activation/:application_id', to: 'loan_activation#activate', as: 'loan_activation_confirm'

    # Lender Dashboard (authenticated lenders only)
    namespace :lender_dashboard do
      get '/', to: 'lender_dashboard#index', as: 'index'
      get 'applications', to: 'lender_dashboard#applications', as: 'applications'
      get 'applications/:id', to: 'lender_dashboard#application_detail', as: 'application_detail'
      get 'payments', to: 'lender_dashboard#payments', as: 'payments'
      get 'reports', to: 'lender_dashboard#reports', as: 'reports'
      get 'account', to: 'lender_dashboard#account', as: 'account'
      patch 'account', to: 'lender_dashboard#update_account', as: 'update_account'
      
      # Webhook management
      resources :webhooks do
        member do
          get :test
          post :test
          get :delivery_log
          post :retry
        end
      end
    end
  end

  # Legal document routes (region-specific contracts, agreements, terms, privacy)
  scope "/legal" do
    get "/", to: "legal#index", as: :legal_index
    get "/contracts/mortgage/:region", to: "legal#mortgage_contract", as: :legal_mortgage_contract
    get "/contracts/wholesale_funder/:region", to: "legal#wholesale_funder_agreement", as: :legal_wholesale_funder
    get "/contracts/investment_management/:region", to: "legal#investment_management_agreement", as: :legal_investment_management
    get "/contracts/referral_partner/:region", to: "legal#referral_partner_agreement", as: :legal_referral_partner
    get "/terms/:region", to: "legal#terms", as: :legal_terms
    get "/privacy/:region", to: "legal#privacy", as: :legal_privacy
  end

  # Default (US) legal pages
  get "privacy-policy", to: "pages#privacy_policy"
  get "terms-of-use", to: "pages#terms_of_use", as: :terms_of_use
  get "terms-and-conditions", to: "pages#terms_and_conditions", as: :terms_and_conditions
  
  # Apply page
  get "apply", to: "pages#apply"

  # React webapp replica (get started flow with inline registration)
  get "get-started", to: "pages#get_started", as: :get_started

  # Hero design previews
  get "hero-option-1", to: "pages#hero_option_1"
  get "hero-option-2", to: "pages#hero_option_2"
  get "hero-option-3", to: "pages#hero_option_3"
  
  # User dashboard
  get "dashboard", to: "dashboard#index"
  get "start-application", to: "dashboard#start_application"
  
  # Games (authenticated users only)
  get "arcade", to: "games#arcade"
  get "honky-pong", to: "games#honky_pong"
  get "lace-invaders", to: "games#lace_invaders"
  get "hackman", to: "games#hackman"
  get "defendher", to: "games#defendher"
  get "hemorrhoids", to: "games#hemorrhoids", as: :hemorrhoids
  

  # Application routes
  resources :applications, except: [:index, :destroy] do
    collection do
      get :autocomplete
      get :get_property_details
      # Demo routes (no authentication required) - Webapp replica flow
      get :demo
      get :demo_spa  # Single Page Application version with animations
      get :demo_property_details
      get :demo_mortgage_details
      get :demo_funding_details
      get :demo_preapproved
      # Legacy demo routes (redirect)
      get :demo_income_loan
      get :demo_summary
    end
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

  # Lender portal routes
  namespace :lender do
    resources :applications, only: [:index, :show] do
      member do
        post :approve
        post :reject
      end
    end
  end

  # Broker portal routes
  devise_for :brokers, controllers: {
    registrations: 'broker/registrations',
    sessions: 'broker/sessions'
  }

  namespace :broker do
    root 'applications#index'
    resources :applications, only: [:index, :show]
    resources :commissions, only: [:index]
    
    # Password setup and reset (no authentication required)
    get '/password/new', to: 'passwords#new'
    post '/password', to: 'passwords#create'
    get '/password/reset/:token', to: 'passwords#edit'
    patch '/password/:token', to: 'passwords#update'
  end

  # Debug routes
  get 'diagnostic/sso_debug', to: 'diagnostic#sso_debug'
  get 'diagnostic/sso_public', to: 'diagnostic#sso_debug_public'

  # SAML metadata route
  get 'saml/metadata', to: 'saml#metadata'

  # Borrower portal routes (EPM loan servicing)
  namespace :borrower do
    root 'applications#index'
    resources :applications, only: [:index, :show] do
      member do
        get :payment_history
        get :documents
        get :download_contract
        get :download_statements
        get :download_key_facts
      end
      resources :messages, only: [:index, :create]
    end
    resources :distributions, only: [] do
      member do
        get :download_receipt
      end
    end
    resources :messages, only: [] do
      member do
        patch :mark_as_read
      end
    end
    resource :account, only: [:show, :edit, :update]
    resource :password, only: [:edit, :update]
  end



  # Defines the root path route ("/")
  root "pages#get_started"
end
