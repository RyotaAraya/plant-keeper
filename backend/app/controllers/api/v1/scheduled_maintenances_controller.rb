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

        rows = maintenances.as_json(include: MAINTENANCE_INCLUDE)
        summaries = tasks_summaries(rows.map { |row| row["id"] })
        render json: {
          data: rows.map { |row| row.merge("tasks_summary" => summaries[row["id"]] || { "total" => 0, "completed" => 0 }) },
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/scheduled_maintenances/:id
      def show
        authorize @maintenance
        tasks = @maintenance.maintenance_tasks.includes(*MaintenanceTasksController::TASK_INCLUDE.keys, :inspections).order(:id)
        render json: {
          data: @maintenance.as_json(include: MAINTENANCE_INCLUDE).merge(
            "maintenance_tasks" => tasks.map { |task| MaintenanceTasksController.task_json(task) },
            "tasks_summary" => tasks_summaries([ @maintenance.id ])[@maintenance.id] || { "total" => 0, "completed" => 0 }
          )
        }
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
          copy_tasks!(copy)
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

      # 作業の進捗（見送りを除く作業の数と、完了した数）。{ 定期整備ID => { total:, completed: } }
      def tasks_summaries(ids)
        counts = MaintenanceTask.where(scheduled_maintenance_id: ids).group(:scheduled_maintenance_id, :status).count
        counts.each_with_object({}) do |((maintenance_id, status), count), result|
          summary = (result[maintenance_id] ||= { "total" => 0, "completed" => 0 })
          summary["total"] += count unless status == "cancelled"
          summary["completed"] += count if status == "completed"
        end
      end

      # 複製の作業: 次回の対象設備に残る設備の作業を引き継ぐ（状態は未着手に戻し、完了日は引き継がない）
      def copy_tasks!(copy)
        @maintenance.maintenance_tasks.where(equipment_id: copy.equipment_ids).find_each do |task|
          copy.maintenance_tasks.create!(
            department_id: task.department_id, equipment_id: task.equipment_id, instrument_id: task.instrument_id, kind: task.kind,
            title: task.title, checklist_template_id: task.checklist_template_id, assigned_to_id: task.assigned_to_id, notes: task.notes
          )
        end
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
