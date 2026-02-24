module Api
  module V1
    class DepartmentHistoriesController < BaseController
      def create
        dh = DepartmentHistory.new(dh_params.merge(started_on: Date.today))
        authorize dh
        if dh.save
          render json: {
            data: dh.as_json(include: { user: { only: [ :id, :name, :email ] } }).merge(started_on: dh.started_on)
          }, status: :created
        else
          render json: { errors: dh.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        dh = DepartmentHistory.find(params[:id])
        authorize dh
        if dh.update(dh_params.slice(:role_note))
          render json: {
            data: dh.as_json(include: { user: { only: [ :id, :name, :email ] } }).merge(started_on: dh.started_on)
          }
        else
          render json: { errors: dh.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        dh = DepartmentHistory.find(params[:id])
        authorize dh
        dh.update(ended_on: Date.today)
        head :no_content
      end

      private

      def dh_params
        params.require(:department_history).permit(:user_id, :department_id, :role_note)
      end
    end
  end
end
