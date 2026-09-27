Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users, path: "api/v1",
    path_names: { sign_in: "login", sign_out: "logout" },
    controllers: { sessions: "api/v1/sessions" }

  namespace :api do
    namespace :v1 do
      resource :current_user, only: [ :show ], controller: "current_user"

      resources :sites, only: [ :index, :show, :create, :update ]
      resources :equipments, only: [ :index, :show, :create, :update ]
      resources :instruments, only: [ :index, :show, :create, :update ]
      resources :equipment_assignments, only: [ :index, :create, :update ]
      resources :regulations, only: [ :index ]
      resources :reference_standards, only: [ :index, :show, :create, :update ] do
        resources :calibrations, only: [ :create, :update ], controller: "reference_standard_calibrations"
      end
      resources :interlocks, only: [ :index, :show, :create, :update ]
      resources :interlock_bypasses, only: [ :index, :show, :create ] do
        member do
          post :approve
          post :reject
          post :start
          post :restore
          post :confirm
          post :cancel
        end
      end
      resources :services, only: [ :index, :create, :update ]
      resources :line_classes, only: [ :index, :create, :update ]
      resources :departments, only: [ :index, :show, :create, :update ]
      resources :department_histories, only: [ :create, :update, :destroy ]
      resources :companies, only: [ :index, :create, :update ]

      # Phase 2: 保全管理
      resources :checklist_templates, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          post :duplicate
          get :item_stats
        end
      end
      resources :inspection_plans, only: [ :index, :create, :update ]
      resources :inspection_plan_groups, only: [ :index, :show, :create, :update ]
      resources :inspections, only: [ :index, :show, :create, :update ]
      # キャリブレータ・校正管理ソフトの校正結果（JSON）の取り込み。確認（preview）→ 取り込み（create）
      resources :calibration_imports, only: [ :create ] do
        collection do
          post :preview
          get :sample
        end
      end
      # 校正の作業指示（5点校正のある点検計画）の書き出し。結果の記録に計画のIDを入れて返すと、取り込みでその計画の点検になる
      resources :calibration_work_orders, only: [ :index, :create ]
      resources :troubles, only: [ :index, :show, :create, :update ] do
        member { post :defer_to_maintenance }
      end
      resources :trouble_responses, only: [ :create, :update ]
      # AI支援（不具合報告の下書き）
      get "ai/status", to: "ai#status"
      post "ai/defect_drafts", to: "ai#defect_draft"
      post "ai/similar_troubles", to: "ai#similar_troubles"
      post "ai/response_drafts", to: "ai#response_draft"
      resources :scheduled_maintenances, only: [ :index, :show, :create, :update ] do
        member do
          get :next_suggestion
          post :duplicate
        end
        resources :tasks, controller: "maintenance_tasks", only: [ :create, :update, :destroy ] do
          collection { post :bulk }
        end
      end
      resources :maintenance_series, only: [ :index, :show, :create, :update ]
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
      get :home, to: "home#show"
      # 外部のシステム（機器管理システム）からの受け口。ユーザのログインではなく、連携用のトークンで認証する
      namespace :integrations do
        post :device_diagnostics, to: "device_diagnostics#create"
      end
      resources :integration_tokens, only: [ :index, :create ] do
        member { post :revoke }
      end

      # Phase 6: 監査ログ
      resources :audit_logs, only: [ :index ]

      # デモ用（認証不要）
      get :demo_accounts, to: "demo#accounts"

      # 管理者用ユーティリティ
      post "admin/reseed", to: "admin#reseed"
      get "admin/reseed", to: "admin#reseed_status"
    end
  end
end
