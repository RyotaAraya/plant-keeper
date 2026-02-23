module Api
  module V1
    class EquipmentAssignmentsController < BaseController
      def index
        authorize EquipmentAssignment
        assignments = EquipmentAssignment.includes(:user, :equipment)
        assignments = assignments.where(equipment_id: params[:equipment_id]) if params[:equipment_id].present?
        assignments = assignments.where(user_id: params[:user_id]) if params[:user_id].present?
        assignments = assignments.order(ended_on: :asc, started_on: :desc)

        render json: {
          data: assignments.as_json(include: {
            user: { only: [ :id, :name, :email, :employment_type, :system_role ] },
            equipment: { only: [ :id, :name ] }
          })
        }
      end

      def create
        assignment = EquipmentAssignment.new(assignment_params)
        authorize assignment
        if assignment.save
          render json: { data: assignment.as_json(include: { user: { only: [ :id, :name ] } }) }, status: :created
        else
          render json: { errors: assignment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        assignment = EquipmentAssignment.find(params[:id])
        authorize assignment
        if assignment.update(assignment_params)
          render json: { data: assignment.as_json(include: { user: { only: [ :id, :name ] } }) }
        else
          render json: { errors: assignment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def assignment_params
        params.require(:equipment_assignment).permit(:user_id, :equipment_id, :role, :started_on, :ended_on)
      end
    end
  end
end
