module Api
  module V1
    class EquipmentsController < BaseController
      before_action :set_equipment, only: [ :show, :update ]

      # GET /api/v1/equipments
      def index
        authorize Equipment
        equipments = Equipment.includes(:site, :regulations).all
        if (site_ids = id_list_param(:site_ids, :site_id))
          equipments = equipments.where(site_id: site_ids)
        end

        equipments = equipments.order(:name)
        total_count = equipments.count

        page, per_page = pagination_params
        equipments = equipments.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: equipments.as_json(include: { site: { only: [ :id, :name ] }, regulations: { only: [ :id, :code, :name ] } }),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/equipments/:id
      def show
        authorize @equipment
        render json: {
          data: @equipment.as_json(
            include: {
              site: { only: [ :id, :name ] },
              regulations: {
                only: [ :id, :code, :name, :law_name, :target ],
                include: { regulation_inspections: { only: [ :id, :name, :interval_days, :basis, :note ] } }
              },
              instruments: { only: [ :id, :tag_number, :instrument_type, :location ] },
              equipment_assignments: {
                include: { user: { only: [ :id, :name, :email, :employment_type, :system_role ] } },
                only: [ :id, :user_id, :role, :started_on, :ended_on ]
              },
              scheduled_maintenances: { only: [ :id, :title, :planned_start_on, :status ] }
            }
          ).merge(
            troubles_count: @equipment.troubles.count
          )
        }
      end

      # POST /api/v1/equipments
      def create
        equipment = Equipment.new(equipment_params)
        authorize equipment

        if equipment.save
          record_audit_log("create", equipment)
          render json: { data: equipment.as_json }, status: :created
        else
          render json: { errors: equipment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/equipments/:id
      def update
        authorize @equipment
        regulation_ids_before = @equipment.regulation_ids.sort
        if @equipment.update(equipment_params)
          record_audit_log("update", @equipment, changes: equipment_changes(regulation_ids_before))
          render json: { data: @equipment.as_json }
        else
          render json: { errors: @equipment.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordInvalid => e
        # 適用法規（regulation_ids）は保存済みの設備では代入した時点で書き込まれるため、不正な区分はここで検知される
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def set_equipment
        @equipment = Equipment.includes(
          :site,
          :instruments,
          :scheduled_maintenances,
          regulations: :regulation_inspections,
          equipment_assignments: :user
        ).find(params[:id])
      end

      def equipment_params
        params.require(:equipment).permit(:name, :description, :site_id, regulation_ids: [])
      end

      # 適用法規の付け外しは saved_changes に出ないため、変更前後のIDを加えて監査ログに残す
      def equipment_changes(regulation_ids_before)
        changes = @equipment.saved_changes.except("updated_at", "created_at")
        regulation_ids_after = @equipment.regulation_ids.sort
        changes["regulation_ids"] = [ regulation_ids_before, regulation_ids_after ] if regulation_ids_before != regulation_ids_after
        changes
      end
    end
  end
end
