module Api
  module V1
    class DepartmentsController < BaseController
      def index
        departments = Department.includes(:site)
        departments = departments.where(site_id: params[:site_id]) if params[:site_id].present?
        departments = departments.where(department_type: params[:department_type]) if params[:department_type].present?

        render json: {
          data: departments.order(:name).as_json(include: { site: { only: [:id, :name] } })
        }
      end

      def create
        department = Department.new(department_params)
        if department.save
          render json: { data: department.as_json(include: { site: { only: [:id, :name] } }) }, status: :created
        else
          render json: { errors: department.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        department = Department.find(params[:id])
        if department.update(department_params)
          render json: { data: department.as_json(include: { site: { only: [:id, :name] } }) }
        else
          render json: { errors: department.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def department_params
        params.require(:department).permit(:name, :department_type, :site_id)
      end
    end
  end
end
