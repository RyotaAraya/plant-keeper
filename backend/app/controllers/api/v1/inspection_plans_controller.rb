module Api
  module V1
    class InspectionPlansController < BaseController
      before_action :set_plan, only: [ :update ]

      # GET /api/v1/inspection_plans
      # overdue=true で期限超過のみ、due_within=N で N日以内に期限が来るもの。既定は有効な計画のみ（is_active=false で無効も）
      def index
        authorize InspectionPlan
        plans = InspectionPlan.includes(:equipment, :instrument, :checklist_template)
        plans = plans.where(is_active: params[:is_active] == "false" ? false : true)
        if (site_ids = id_list_param(:site_ids, :site_id))
          plans = plans.where(equipment_id: Equipment.where(site_id: site_ids).select(:id))
        end
        if (equipment_ids = id_list_param(:equipment_ids, :equipment_id))
          plans = plans.where(equipment_id: equipment_ids)
        end
        plans = plans.overdue if params[:overdue] == "true"
        plans = plans.due_within(params[:due_within].to_i) if params[:due_within].present?

        plans = plans.order(:next_due_on, :id)
        total_count = plans.count

        page, per_page = pagination_params
        plans = plans.limit(per_page).offset((page - 1) * per_page)

        render json: { data: plans.map { |plan| plan_json(plan) }, meta: { total_count: total_count, page: page, per_page: per_page } }
      end

      # POST /api/v1/inspection_plans
      def create
        plan = InspectionPlan.new(plan_params)
        authorize plan
        if plan.save
          record_audit_log("create", plan)
          render json: { data: plan_json(plan) }, status: :created
        else
          render json: { errors: plan.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/inspection_plans/:id
      def update
        authorize @plan
        if @plan.update(plan_params)
          record_audit_log("update", @plan)
          render json: { data: plan_json(@plan) }
        else
          render json: { errors: @plan.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_plan
        @plan = InspectionPlan.find(params[:id])
      end

      def plan_json(plan)
        plan.as_json(
          methods: [ :overdue, :days_until_due ],
          include: {
            equipment: { only: [ :id, :name, :site_id ] },
            instrument: { only: [ :id, :tag_number ] },
            checklist_template: { only: [ :id, :name ] }
          }
        )
      end

      def plan_params
        params.require(:inspection_plan).permit(
          :name, :equipment_id, :instrument_id, :checklist_template_id, :inspection_type,
          :interval_days, :next_due_on, :is_active
        )
      end
    end
  end
end
