module Api
  module V1
    class TroublesController < BaseController
      # 「定期整備に回す」の、回し先の指定の誤り（422で返す）
      class DeferTargetError < StandardError; end

      before_action :set_trouble, only: [ :show, :update, :defer_to_maintenance ]

      # GET /api/v1/troubles
      def index
        authorize Trouble
        troubles = Trouble.includes(:equipment, :instrument, reported_by: :department, assigned_to: :department).all
        if (site_ids = id_list_param(:site_ids, :site_id))
          troubles = troubles.where(equipment_id: Equipment.where(site_id: site_ids).select(:id))
        end
        if (equipment_ids = id_list_param(:equipment_ids, :equipment_id))
          troubles = troubles.where(equipment_id: equipment_ids)
        end
        troubles = troubles.where(instrument_id: params[:instrument_id]) if params[:instrument_id].present?
        if (statuses = value_list_param(:statuses, :status))
          troubles = troubles.where(status: statuses)
        end
        if (priorities = value_list_param(:priorities, :priority))
          troubles = troubles.where(priority: priorities)
        end
        troubles = troubles.where(assigned_to_id: params[:assigned_to_id]) if params[:assigned_to_id].present?
        if params[:department_id].present?
          troubles = troubles.for_departments(Department.subtree_ids(params[:department_id]))
        end

        if params[:q].present?
          troubles = troubles.where("title ILIKE ?", "%#{params[:q]}%")
        end

        troubles = troubles.order(reported_at: :desc)
        total_count = troubles.count

        page, per_page = pagination_params
        troubles = troubles.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: troubles.as_json(
            include: {
              equipment: { only: [ :id, :name ] },
              instrument: { only: [ :id, :tag_number ] },
              reported_by: { only: [ :id, :name ], include: { department: { only: [ :id, :name ] } } },
              assigned_to: { only: [ :id, :name ], include: { department: { only: [ :id, :name ] } } }
            }
          ),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/troubles/:id
      def show
        authorize @trouble
        render json: {
          data: @trouble.as_json(
            include: {
              equipment: { only: [ :id, :name, :site_id ] },
              instrument: { only: [ :id, :tag_number ] },
              reported_by: { only: [ :id, :name ] },
              assigned_to: { only: [ :id, :name ] },
              inspection_item: {
                only: [ :id, :content, :measured_value ],
                include: { inspection: { only: [ :id, :inspected_at, :inspection_type ] } }
              },
              trouble_responses: {
                include: { user: { only: [ :id, :name ] } }
              },
              maintenance_tasks: {
                only: [ :id, :title, :status, :scheduled_maintenance_id ],
                include: { scheduled_maintenance: { only: [ :id, :title, :status ] } }
              }
            }
          )
        }
      end

      # POST /api/v1/troubles/:id/defer_to_maintenance
      # 運転中に直せないトラブルを、定期整備の作業（整備）に回し、トラブルを「定修待ち」にする。
      # 回し先は、既存の定期整備（scheduled_maintenance_id。計画中・準備中）か、新しく作る単一設備の定期整備（new_maintenance）。
      # トラブルの設備が回し先の対象設備になければ、追加する
      def defer_to_maintenance
        authorize @trouble, :defer_to_maintenance?
        unless %w[open in_progress].include?(@trouble.status)
          return render json: { errors: [ "定修待ちにできるのは、未対応・対応中のトラブルだけです" ] }, status: :unprocessable_entity
        end
        if @trouble.active_maintenance_task
          return render json: { errors: [ "すでに定期整備の作業に回されています" ] }, status: :unprocessable_entity
        end

        task = equipment_added = maintenance = nil
        ActiveRecord::Base.transaction do
          maintenance = target_maintenance!
          equipment_added = maintenance.equipment_ids.exclude?(@trouble.equipment_id)
          if equipment_added
            maintenance.update!(equipment_ids: maintenance.equipment_ids + [ @trouble.equipment_id ])
            record_audit_log("update", maintenance, changes: { "equipment_ids" => [ maintenance.equipment_ids - [ @trouble.equipment_id ], maintenance.equipment_ids ] })
          end
          task = maintenance.maintenance_tasks.create!(
            equipment_id: @trouble.equipment_id, instrument_id: @trouble.instrument_id, kind: "overhaul", title: @trouble.title,
            notes: @trouble.description, department_id: params[:department_id].presence, trouble: @trouble
          )
          record_audit_log("create", task)
          @trouble.update!(status: "deferred")
          record_audit_log("update", @trouble)
        end

        render json: {
          data: { task: MaintenanceTasksController.task_json(task), maintenance: maintenance.as_json(only: [ :id, :title, :status ]), equipment_added: equipment_added }
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      rescue DeferTargetError => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      end

      # POST /api/v1/troubles
      def create
        trouble = Trouble.new(trouble_params)
        authorize trouble
        trouble.reported_by = current_user

        if trouble.save
          record_audit_log("create", trouble)
          render json: { data: trouble.as_json }, status: :created
        else
          render json: { errors: trouble.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/troubles/:id
      def update
        authorize @trouble
        if @trouble.update(trouble_params)
          record_audit_log("update", @trouble)
          render json: {
            data: @trouble.as_json(
              include: {
                equipment: { only: [ :id, :name ] },
                instrument: { only: [ :id, :tag_number ] },
                assigned_to: { only: [ :id, :name ] }
              }
            )
          }
        else
          render json: { errors: @trouble.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      # 回し先の定期整備。既存（計画中・準備中で、トラブルの設備と同じ拠点）か、新規（トラブルの設備だけを対象にする）
      def target_maintenance!
        site_id = @trouble.equipment.site_id
        if params[:scheduled_maintenance_id].present?
          maintenance = ScheduledMaintenance.find(params[:scheduled_maintenance_id])
          raise DeferTargetError, "計画中・準備中の定期整備にだけ回せます" unless %w[planned preparing].include?(maintenance.status)
          raise DeferTargetError, "トラブルの設備と同じ拠点の定期整備を選んでください" unless maintenance.site_id == site_id

          maintenance
        elsif params[:new_maintenance].present?
          new_params = params.require(:new_maintenance).permit(:title, :planned_start_on, :planned_end_on)
          maintenance = ScheduledMaintenance.create!(new_params.merge(site_id: site_id, equipment_ids: [ @trouble.equipment_id ]))
          record_audit_log("create", maintenance)
          maintenance
        else
          raise DeferTargetError, "回し先の定期整備を選ぶか、新しい定期整備を指定してください"
        end
      end

      def set_trouble
        @trouble = Trouble.includes(
          :equipment, :instrument, :reported_by, :assigned_to,
          :inspection_item, :maintenance_tasks,
          trouble_responses: :user
        ).find(params[:id])
      end

      def trouble_params
        params.require(:trouble).permit(
          :equipment_id, :instrument_id, :assigned_to_id,
          :title, :description, :status, :priority, :reported_at
        )
      end
    end
  end
end
