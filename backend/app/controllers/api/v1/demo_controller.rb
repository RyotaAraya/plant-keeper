module Api
  module V1
    class DemoController < ApplicationController
      def accounts
        users = User.includes(:company, department: { parent: :parent })
                    .where(is_active: true)
                    .order(:system_role, :name)

        render json: {
          data: users.map { |u|
            {
              id: u.id,
              name: u.name,
              email: u.email,
              system_role: u.system_role,
              employment_type: u.employment_type,
              company_name: u.company&.name,
              department_path: u.department&.full_path
            }
          }
        }
      end
    end
  end
end
