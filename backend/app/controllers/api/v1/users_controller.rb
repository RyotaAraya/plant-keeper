module Api
  module V1
    class UsersController < BaseController
      before_action :set_user, only: [ :show, :update ]

      # GET /api/v1/users
      def index
        users = User.includes(:company, department: { parent: :parent }).all
        users = users.where(company_id: params[:company_id]) if params[:company_id].present?
        users = users.where(department_id: params[:department_id]) if params[:department_id].present?
        users = users.where(employment_type: params[:employment_type]) if params[:employment_type].present?
        users = users.where(system_role: params[:system_role]) if params[:system_role].present?
        users = users.where(is_active: params[:is_active]) if params[:is_active].present?

        if params[:q].present?
          users = users.where("name ILIKE ? OR email ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
        end

        users = users.order(:name)

        render json: {
          data: users.map { |u| user_json(u) }
        }
      end

      # GET /api/v1/users/:id
      def show
        json = user_json(@user)
        json[:equipment_assignments] = @user.equipment_assignments.as_json(
          only: [ :id, :equipment_id, :role, :started_on, :ended_on ],
          include: { equipment: { only: [ :id, :name ] } }
        )
        render json: { data: json }
      end

      # PATCH /api/v1/users/:id
      def update
        if @user.update(user_params)
          @user.reload
          render json: { data: user_json(@user) }
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_user
        @user = User.includes(:company, department: { parent: :parent }, equipment_assignments: :equipment).find(params[:id])
      end

      def user_json(user)
        json = user.as_json(only: [ :id, :email, :name, :employment_type, :system_role, :company_id, :department_id, :is_active, :join_year, :home_prefecture, :previous_company, :deactivated_on, :position, :created_at ])
        if user.company
          json[:company] = { id: user.company.id, name: user.company.name, company_type: user.company.company_type }
        end
        if user.department
          json[:department] = {
            id: user.department.id,
            name: user.department.name,
            level: user.department.level,
            site_id: user.department.site_id,
            full_path: user.department.full_path,
            ancestors: user.department.ancestor_chain
          }
        end
        json
      end

      def user_params
        params.require(:user).permit(
          :name, :employment_type, :system_role, :company_id, :department_id, :is_active,
          :join_year, :home_prefecture, :previous_company, :deactivated_on
        )
      end
    end
  end
end
