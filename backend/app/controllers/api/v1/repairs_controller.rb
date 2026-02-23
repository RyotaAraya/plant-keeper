module Api
  module V1
    class RepairsController < BaseController
      before_action :set_repair, only: [ :show, :update ]

      # GET /api/v1/repairs
      def index
        authorize Repair
        repairs = Repair.includes(:stock, :requested_by, stock: :material).all
        repairs = repairs.where(status: params[:status]) if params[:status].present?

        repairs = repairs.order(created_at: :desc)
        total_count = repairs.count

        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        repairs = repairs.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: repairs.as_json(
            include: {
              stock: { include: { material: { only: [ :id, :name, :part_number ] } }, only: [ :id, :serial_number ] },
              requested_by: { only: [ :id, :name ] }
            }
          ),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/repairs/:id
      def show
        authorize @repair
        render json: {
          data: @repair.as_json(
            include: {
              stock: {
                include: {
                  material: { only: [ :id, :name, :part_number ] },
                  warehouse: { only: [ :id, :name ] }
                }
              },
              trouble: { only: [ :id, :title, :status ] },
              requested_by: { only: [ :id, :name ] }
            }
          )
        }
      end

      # POST /api/v1/repairs
      def create
        repair = Repair.new(repair_params)
        authorize repair
        repair.requested_by = current_user

        if repair.save
          repair.stock&.update(status: "awaiting_repair")
          render json: { data: repair.as_json }, status: :created
        else
          render json: { errors: repair.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/repairs/:id
      def update
        authorize @repair
        if @repair.update(repair_params)
          case @repair.status
          when "shipped"
            @repair.stock&.update(status: "under_repair")
          when "completed"
            @repair.stock&.update(status: "available")
          when "disposed"
            @repair.stock&.update(status: "disposed")
          end
          render json: { data: @repair.as_json }
        else
          render json: { errors: @repair.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_repair
        @repair = Repair.includes(:stock, :trouble, :requested_by, stock: [ :material, :warehouse ]).find(params[:id])
      end

      def repair_params
        params.require(:repair).permit(
          :stock_id, :trouble_id, :status, :repair_vendor,
          :shipped_on, :completed_on, :received_on,
          :repair_cost, :shipping_cost, :disposition, :notes
        )
      end
    end
  end
end
