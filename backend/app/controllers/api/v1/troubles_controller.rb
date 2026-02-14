module Api
  module V1
    class TroublesController < BaseController
      before_action :set_trouble, only: [:show, :update]

      # GET /api/v1/troubles
      def index
        troubles = Trouble.includes(:equipment, :instrument, :reported_by, :assigned_to).all
        troubles = troubles.where(equipment_id: params[:equipment_id]) if params[:equipment_id].present?
        troubles = troubles.where(instrument_id: params[:instrument_id]) if params[:instrument_id].present?
        troubles = troubles.where(status: params[:status]) if params[:status].present?
        troubles = troubles.where(priority: params[:priority]) if params[:priority].present?
        troubles = troubles.where(assigned_to_id: params[:assigned_to_id]) if params[:assigned_to_id].present?

        if params[:q].present?
          troubles = troubles.where("title ILIKE ?", "%#{params[:q]}%")
        end

        troubles = troubles.order(reported_at: :desc)
        total_count = troubles.count

        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        troubles = troubles.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: troubles.as_json(
            include: {
              equipment: { only: [:id, :name] },
              instrument: { only: [:id, :tag_number] },
              reported_by: { only: [:id, :name] },
              assigned_to: { only: [:id, :name] }
            }
          ),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/troubles/:id
      def show
        render json: {
          data: @trouble.as_json(
            include: {
              equipment: { only: [:id, :name] },
              instrument: { only: [:id, :tag_number] },
              reported_by: { only: [:id, :name] },
              assigned_to: { only: [:id, :name] },
              inspection_item: {
                only: [:id, :content, :measured_value],
                include: { inspection: { only: [:id, :inspected_at, :inspection_type] } }
              },
              trouble_responses: {
                include: { user: { only: [:id, :name] } }
              }
            }
          )
        }
      end

      # POST /api/v1/troubles
      def create
        trouble = Trouble.new(trouble_params)
        trouble.reported_by = current_user

        if trouble.save
          render json: { data: trouble.as_json }, status: :created
        else
          render json: { errors: trouble.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/troubles/:id
      def update
        if @trouble.update(trouble_params)
          render json: {
            data: @trouble.as_json(
              include: {
                equipment: { only: [:id, :name] },
                instrument: { only: [:id, :tag_number] },
                assigned_to: { only: [:id, :name] }
              }
            )
          }
        else
          render json: { errors: @trouble.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_trouble
        @trouble = Trouble.includes(
          :equipment, :instrument, :reported_by, :assigned_to,
          :inspection_item,
          trouble_responses: :user
        ).find(params[:id])
      end

      def trouble_params
        params.require(:trouble).permit(
          :equipment_id, :instrument_id, :assigned_to_id,
          :title, :description, :status, :priority, :reported_at, :resolved_at
        )
      end
    end
  end
end
