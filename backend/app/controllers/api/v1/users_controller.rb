module Api
  module V1
    class UsersController < BaseController
      before_action :set_user, only: [:show, :update]

      # GET /api/v1/users
      def index
        users = User.includes(:department).all
        users = users.where(department_id: params[:department_id]) if params[:department_id].present?
        users = users.where(role: params[:role]) if params[:role].present?
        users = users.where(is_active: params[:is_active]) if params[:is_active].present?

        if params[:q].present?
          users = users.where("name ILIKE ? OR email ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
        end

        users = users.order(:name)

        render json: {
          data: users.as_json(
            only: [:id, :email, :name, :role, :department_id, :is_active, :join_year, :home_prefecture, :previous_company, :deactivated_on],
            include: { department: { only: [:id, :name] } }
          )
        }
      end

      # GET /api/v1/users/:id
      def show
        render json: {
          data: @user.as_json(
            only: [:id, :email, :name, :role, :department_id, :is_active, :join_year, :home_prefecture, :previous_company, :deactivated_on, :created_at],
            include: {
              department: { only: [:id, :name] },
              equipment_assignments: {
                include: { equipment: { only: [:id, :name] } },
                only: [:id, :equipment_id, :role, :started_on, :ended_on]
              }
            }
          )
        }
      end

      # PATCH /api/v1/users/:id
      def update
        if @user.update(user_params)
          render json: {
            data: @user.as_json(
              only: [:id, :email, :name, :role, :department_id, :is_active, :join_year, :home_prefecture, :previous_company, :deactivated_on],
              include: { department: { only: [:id, :name] } }
            )
          }
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_user
        @user = User.includes(:department, equipment_assignments: :equipment).find(params[:id])
      end

      def user_params
        params.require(:user).permit(
          :name, :role, :department_id, :is_active,
          :join_year, :home_prefecture, :previous_company, :deactivated_on
        )
      end
    end
  end
end
