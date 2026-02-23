module Api
  module V1
    class ScheduledMaintenancesController < BaseController
      before_action :set_maintenance, only: [ :show, :update ]

      # GET /api/v1/scheduled_maintenances
      def index
        maintenances = ScheduledMaintenance.includes(:equipment, maintenance_assignments: :user).all
        maintenances = maintenances.where(equipment_id: params[:equipment_id]) if params[:equipment_id].present?
        maintenances = maintenances.where(status: params[:status]) if params[:status].present?

        maintenances = maintenances.order(scheduled_date: :desc)
        total_count = maintenances.count

        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        maintenances = maintenances.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: maintenances.as_json(
            include: {
              equipment: { only: [ :id, :name ] },
              maintenance_assignments: {
                include: { user: { only: [ :id, :name ] } },
                only: [ :id, :user_id, :role ]
              }
            }
          ),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/scheduled_maintenances/:id
      def show
        render json: {
          data: @maintenance.as_json(
            include: {
              equipment: { only: [ :id, :name ] },
              maintenance_assignments: {
                include: { user: { only: [ :id, :name ] } },
                only: [ :id, :user_id, :role ]
              }
            }
          )
        }
      end

      # POST /api/v1/scheduled_maintenances
      def create
        maintenance = ScheduledMaintenance.new(maintenance_params)
        authorize maintenance

        ActiveRecord::Base.transaction do
          maintenance.save!

          if params[:scheduled_maintenance][:assignments].present?
            params[:scheduled_maintenance][:assignments].each do |assignment|
              maintenance.maintenance_assignments.create!(
                user_id: assignment[:user_id],
                role: assignment[:role] || "member"
              )
            end
          end
        end

        maintenance.reload
        render json: {
          data: maintenance.as_json(
            include: { maintenance_assignments: { include: { user: { only: [ :id, :name ] } } } }
          )
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      end

      # PATCH /api/v1/scheduled_maintenances/:id
      def update
        authorize @maintenance
        ActiveRecord::Base.transaction do
          @maintenance.update!(maintenance_params)

          if params[:scheduled_maintenance][:assignments].present?
            @maintenance.maintenance_assignments.destroy_all
            params[:scheduled_maintenance][:assignments].each do |assignment|
              @maintenance.maintenance_assignments.create!(
                user_id: assignment[:user_id],
                role: assignment[:role] || "member"
              )
            end
          end
        end

        @maintenance.reload
        render json: {
          data: @maintenance.as_json(
            include: {
              equipment: { only: [ :id, :name ] },
              maintenance_assignments: {
                include: { user: { only: [ :id, :name ] } },
                only: [ :id, :user_id, :role ]
              }
            }
          )
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      end

      private

      def set_maintenance
        @maintenance = ScheduledMaintenance.includes(
          :equipment,
          maintenance_assignments: :user
        ).find(params[:id])
      end

      def maintenance_params
        params.require(:scheduled_maintenance).permit(
          :equipment_id, :title, :description,
          :scheduled_date, :completed_date, :status, :used_materials
        )
      end
    end
  end
end
