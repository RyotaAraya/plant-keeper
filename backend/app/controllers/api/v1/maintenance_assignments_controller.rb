module Api
  module V1
    class MaintenanceAssignmentsController < BaseController
      # POST /api/v1/maintenance_assignments
      def create
        assignment = MaintenanceAssignment.new(assignment_params)
        authorize assignment

        if assignment.save
          render json: {
            data: assignment.as_json(include: { user: { only: [ :id, :name ] } })
          }, status: :created
        else
          render json: { errors: assignment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/maintenance_assignments/:id
      def destroy
        assignment = MaintenanceAssignment.find(params[:id])
        authorize assignment
        assignment.destroy!
        head :no_content
      end

      private

      def assignment_params
        params.require(:maintenance_assignment).permit(:scheduled_maintenance_id, :user_id, :role)
      end
    end
  end
end
