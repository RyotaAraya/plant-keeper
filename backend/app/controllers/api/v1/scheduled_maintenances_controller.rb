module Api
  module V1
    class ScheduledMaintenancesController < BaseController
      before_action :set_maintenance, only: [ :show, :update, :next_suggestion, :duplicate ]

      MAINTENANCE_INCLUDE = {
        site: { only: [ :id, :name ] },
        maintenance_series: { only: [ :id, :name ] },
        equipments: { only: [ :id, :name, :site_id ] },
        accepted_by: { only: [ :id, :name ] },
        maintenance_assignments: {
          include: { user: { only: [ :id, :name ] } },
          only: [ :id, :user_id, :role ]
        }
      }.freeze

      # GET /api/v1/scheduled_maintenances
      def index
        authorize ScheduledMaintenance
        maintenances = ScheduledMaintenance.includes(:site, :equipments, :accepted_by, maintenance_assignments: :user)
        if (site_ids = id_list_param(:site_ids, :site_id))
          maintenances = maintenances.where(site_id: site_ids)
        end
        # 対象設備のどれかが一致する定期整備
        if (equipment_ids = id_list_param(:equipment_ids, :equipment_id))
          maintenances = maintenances.where(id: ScheduledMaintenanceEquipment.where(equipment_id: equipment_ids).select(:scheduled_maintenance_id))
        end
        if (statuses = value_list_param(:statuses, :status))
          maintenances = maintenances.where(status: statuses)
        end

        maintenances = maintenances.order(planned_start_on: :desc, id: :desc)
        total_count = maintenances.count

        page, per_page = pagination_params
        maintenances = maintenances.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: maintenances.as_json(include: MAINTENANCE_INCLUDE),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/scheduled_maintenances/:id
      def show
        authorize @maintenance
        render json: { data: @maintenance.as_json(include: MAINTENANCE_INCLUDE) }
      end

      # GET /api/v1/scheduled_maintenances/:id/next_suggestion
      # 「次回を作る」の提案（名称・日付・対象設備とその理由）。作成はしない
      def next_suggestion
        authorize @maintenance, :next_suggestion?
        render json: { data: MaintenanceSuccessor.new(@maintenance).suggestion }
      end

      # POST /api/v1/scheduled_maintenances/:id/duplicate
      # 次回の定期整備を、複製で作る（系列・説明・担当者を引き継ぎ、状態は計画中。検収・実績・使用資材は引き継がない）。
      # 名称・日付・対象設備は、提案を確認して直したものを受け取る
      def duplicate
        authorize @maintenance, :duplicate?
        copy = ScheduledMaintenance.new(duplicate_params.merge(
          site_id: @maintenance.site_id, maintenance_series_id: @maintenance.maintenance_series_id, description: @maintenance.description
        ))

        ActiveRecord::Base.transaction do
          copy.save!
          record_audit_log("create", copy)
          @maintenance.maintenance_assignments.each { |assignment| copy.maintenance_assignments.create!(user_id: assignment.user_id, role: assignment.role) }
        end

        render json: { data: copy.reload.as_json(include: MAINTENANCE_INCLUDE) }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # POST /api/v1/scheduled_maintenances
      # 新規は計画中で作る（状態は、作成後に遷移で進める）。拠点は、省略すれば対象設備の拠点
      def create
        maintenance = ScheduledMaintenance.new(create_params)
        maintenance.site_id ||= maintenance.equipments.first&.site_id
        authorize maintenance

        ActiveRecord::Base.transaction do
          maintenance.save!
          record_audit_log("create", maintenance)
          replace_assignments!(maintenance)
        end

        maintenance.reload
        render json: { data: maintenance.as_json(include: MAINTENANCE_INCLUDE) }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # PATCH /api/v1/scheduled_maintenances/:id
      def update
        authorize @maintenance
        equipment_ids_before = @maintenance.equipment_ids.sort

        ActiveRecord::Base.transaction do
          # 対象設備（equipment_ids）は保存済みの定期整備では代入した時点で書き込まれる。不正なら update! で検証され、まとめて戻る
          @maintenance.assign_attributes(update_params)
          @maintenance.accepted_by_id ||= current_user.id if @maintenance.accepted_on.present?
          @maintenance.save!
          record_audit_log("update", @maintenance, changes: maintenance_changes(equipment_ids_before))
          replace_assignments!(@maintenance)
        end

        @maintenance.reload
        render json: { data: @maintenance.as_json(include: MAINTENANCE_INCLUDE) }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def set_maintenance
        @maintenance = ScheduledMaintenance.includes(:site, :equipments, :accepted_by, maintenance_assignments: :user).find(params[:id])
      end

      # assignments が送られたときだけ、担当者を送られた内容に置き換える
      def replace_assignments!(maintenance)
        assignments = params[:scheduled_maintenance][:assignments]
        return if assignments.blank?

        maintenance.maintenance_assignments.destroy_all
        assignments.each do |assignment|
          maintenance.maintenance_assignments.create!(user_id: assignment[:user_id], role: assignment[:role] || "member")
        end
      end

      # 対象設備の付け外しは saved_changes に出ないため、変更前後のIDを加えて監査ログに残す
      def maintenance_changes(equipment_ids_before)
        changes = @maintenance.saved_changes.except("updated_at", "created_at")
        equipment_ids_after = @maintenance.equipment_ids.sort
        changes["equipment_ids"] = [ equipment_ids_before, equipment_ids_after ] if equipment_ids_before != equipment_ids_after
        changes
      end

      def duplicate_params
        params.require(:scheduled_maintenance).permit(:title, :planned_start_on, :planned_end_on, equipment_ids: [])
      end

      def create_params
        params.require(:scheduled_maintenance).permit(
          :site_id, :title, :description, :planned_start_on, :planned_end_on, :used_materials, equipment_ids: []
        )
      end

      def update_params
        params.require(:scheduled_maintenance).permit(
          :title, :description, :planned_start_on, :planned_end_on, :actual_start_on, :actual_end_on, :used_materials, :status,
          :accepted_on, :accepted_by_id, :acceptance_result, :acceptance_notes, :maintenance_series_id, equipment_ids: []
        )
      end
    end
  end
end
