module Api
  module V1
    class EquipmentsController < BaseController
      before_action :set_equipment, only: [ :show, :update ]

      # GET /api/v1/equipments
      def index
        equipments = Equipment.includes(:site).all
        equipments = equipments.where(site_id: params[:site_id]) if params[:site_id].present?

        equipments = equipments.order(:name)
        total_count = equipments.count

        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        equipments = equipments.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: equipments.as_json(include: { site: { only: [ :id, :name ] } }),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/equipments/:id
      def show
        render json: {
          data: @equipment.as_json(
            include: {
              site: { only: [ :id, :name ] },
              instruments: { only: [ :id, :tag_number, :instrument_type, :location ] },
              equipment_assignments: {
                include: { user: { only: [ :id, :name, :email, :employment_type, :system_role ] } },
                only: [ :id, :user_id, :role, :started_on, :ended_on ]
              },
              scheduled_maintenances: { only: [ :id, :title, :scheduled_date, :status ] }
            }
          ).merge(
            troubles_count: @equipment.troubles.count
          )
        }
      end

      # POST /api/v1/equipments
      def create
        equipment = Equipment.new(equipment_params)

        if equipment.save
          render json: { data: equipment.as_json }, status: :created
        else
          render json: { errors: equipment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/equipments/:id
      def update
        if @equipment.update(equipment_params)
          render json: { data: @equipment.as_json }
        else
          render json: { errors: @equipment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_equipment
        @equipment = Equipment.includes(
          :site,
          :instruments,
          :scheduled_maintenances,
          equipment_assignments: :user
        ).find(params[:id])
      end

      def equipment_params
        params.require(:equipment).permit(:name, :description, :site_id)
      end
    end
  end
end
