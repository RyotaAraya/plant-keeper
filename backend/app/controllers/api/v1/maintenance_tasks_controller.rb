module Api
  module V1
    # 定期整備の作業（部署ごとの、設備・計器の点検や整備）
    class MaintenanceTasksController < BaseController
      before_action :set_maintenance
      before_action :set_task, only: [ :update, :destroy ]

      TASK_INCLUDE = {
        department: { only: [ :id, :name ] },
        equipment: { only: [ :id, :name ] },
        instrument: { only: [ :id, :tag_number ] },
        checklist_template: { only: [ :id, :name ] },
        assigned_to: { only: [ :id, :name ] },
        trouble: { only: [ :id, :title, :status ] }
      }.freeze

      # 定期整備の詳細から使う。作業ごとの、最後の点検（記録した点検のうち新しいもの）を付ける
      def self.task_json(task)
        latest = task.inspections.max_by(&:inspected_at)
        task.as_json(include: TASK_INCLUDE).merge("latest_inspection" => latest&.as_json(only: [ :id, :status, :inspected_at ]))
      end

      # POST /api/v1/scheduled_maintenances/:scheduled_maintenance_id/tasks
      def create
        task = @maintenance.maintenance_tasks.build(create_params)
        authorize task

        ActiveRecord::Base.transaction do
          task.save!
          record_audit_log("create", task)
        end
        render json: { data: self.class.task_json(task) }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # PATCH /api/v1/scheduled_maintenances/:scheduled_maintenance_id/tasks/:id
      # 状態・備考は誰でも。構成（部署・対象・内容・担当者など）は管理者と自社のマネージャーだけ
      def update
        authorize @task
        ActiveRecord::Base.transaction do
          @task.update!(policy(@task).manage? ? manager_params : field_worker_params)
          record_audit_log("update", @task)
        end
        render json: { data: self.class.task_json(@task) }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # DELETE /api/v1/scheduled_maintenances/:scheduled_maintenance_id/tasks/:id
      def destroy
        authorize @task
        ActiveRecord::Base.transaction do
          @task.destroy!
          record_audit_log("delete", @task, changes: @task.attributes.except("created_at", "updated_at"))
        end
        head :no_content
      end

      # POST /api/v1/scheduled_maintenances/:scheduled_maintenance_id/tasks/bulk
      # 設備の計器を、種類ごとの定修点検のチェックリストつきで、点検の作業として追加する。
      # すでに作業のある計器と、テンプレートのない計器（手動弁など）は飛ばす
      def bulk
        authorize MaintenanceTask, :bulk?
        equipment = @maintenance.equipments.find(params[:equipment_id])
        existing = @maintenance.maintenance_tasks.kind_inspection.where.not(instrument_id: nil).pluck(:instrument_id)
        templates = {}
        created = []
        skipped = unsupported = 0

        ActiveRecord::Base.transaction do
          equipment.instruments.order(:tag_number).each do |instrument|
            key = MaintenanceTask.template_key_for(instrument)
            template = key && (templates[key] ||= MaintenanceTask.turnaround_template_for(instrument))
            if template.nil?
              unsupported += 1
            elsif existing.include?(instrument.id)
              skipped += 1
            else
              task = @maintenance.maintenance_tasks.create!(equipment: equipment, instrument: instrument, department_id: params[:department_id].presence,
                                                            kind: "inspection", checklist_template: template)
              record_audit_log("create", task)
              created << task
            end
          end
        end

        render json: { data: created.map { |task| self.class.task_json(task) }, meta: { created: created.size, skipped_existing: skipped, unsupported: unsupported } }, status: :created
      end

      private

      def set_maintenance
        @maintenance = ScheduledMaintenance.find(params[:scheduled_maintenance_id])
      end

      def set_task
        @task = @maintenance.maintenance_tasks.find(params[:id])
      end

      def create_params
        params.require(:maintenance_task).permit(:department_id, :equipment_id, :instrument_id, :checklist_template_id, :assigned_to_id, :kind, :title, :notes)
      end

      def manager_params
        params.require(:maintenance_task).permit(:department_id, :equipment_id, :instrument_id, :checklist_template_id, :assigned_to_id, :kind, :title, :status, :completed_on, :notes)
      end

      def field_worker_params
        params.require(:maintenance_task).permit(:status, :notes)
      end
    end
  end
end
