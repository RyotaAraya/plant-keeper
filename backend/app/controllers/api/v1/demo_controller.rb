module Api
  module V1
    class DemoController < ApplicationController
      # ログイン画面に出すデモアカウント。権限（自社/協力会社 × 管理者・業務管理者・一般・技能員）ごとに1人ずつ。
      # 全ユーザを出すと数十人になり、選べなくなるため。データとしてのユーザ（点検の実施者など）は減らさない
      DEMO_ACCOUNT_EMAILS = %w[
        admin@example.com
        suzuki@example.com
        sato@example.com
        yoshida@example.com
        honda@example.com
      ].freeze

      def accounts
        users = User.includes(:company, department: { parent: :parent })
                    .where(is_active: true, email: DEMO_ACCOUNT_EMAILS)
                    .sort_by { |u| DEMO_ACCOUNT_EMAILS.index(u.email) }

        render json: {
          data: users.map { |u|
            {
              id: u.id,
              name: u.name,
              email: u.email,
              system_role: u.system_role,
              employment_type: u.employment_type,
              company_name: u.company&.name,
              company_type: u.company&.company_type,
              department_path: u.department&.full_path
            }
          }
        }
      end
    end
  end
end
