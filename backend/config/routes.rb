Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users, path: "api/v1",
    path_names: { sign_in: "login", sign_out: "logout", registration: "signup" },
    controllers: {
      sessions: "api/v1/sessions",
      registrations: "api/v1/registrations"
    }

  namespace :api do
    namespace :v1 do
      resource :current_user, only: [ :show ], controller: "current_user"

      resources :sites, only: [ :index, :show, :create, :update ]
      resources :equipments, only: [ :index, :show, :create, :update ]
      resources :instruments, only: [ :index, :show, :create, :update ]
      resources :equipment_assignments, only: [ :index, :create, :update ]
      resources :services, only: [ :index, :create, :update ]
      resources :line_classes, only: [ :index, :create, :update ]
      resources :departments, only: [ :index, :create, :update ]
      resources :companies, only: [ :index, :create, :update ]

      # Phase 2: 保全管理
      resources :checklist_templates, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          post :duplicate
        end
      end
      resources :inspections, only: [ :index, :show, :create, :update ]
      resources :troubles, only: [ :index, :show, :create, :update ]
      resources :trouble_responses, only: [ :create, :update ]
      resources :scheduled_maintenances, only: [ :index, :show, :create, :update ]
      resources :maintenance_assignments, only: [ :create, :destroy ]

      # Phase 3: 資材管理
      resources :manufacturers, only: [ :index, :create, :update ]
      resources :materials, only: [ :index, :show, :create, :update ]
      resources :warehouses, only: [ :index, :create, :update ]
      resources :stocks, only: [ :index, :show, :create, :update ]
      resources :stock_transactions, only: [ :create ]
      resources :repairs, only: [ :index, :show, :create, :update ]
      resources :orders, only: [ :index, :show, :create, :update ]

      # Phase 4: ユーザ管理
      resources :users, only: [ :index, :show, :update ]

      # Phase 5: ダッシュボード
      get :dashboard, to: "dashboard#show"

      # Phase 6: 監査ログ
      resources :audit_logs, only: [ :index ]

      # デモ用（認証不要）
      get :demo_accounts, to: "demo#accounts"
    end
  end
end
