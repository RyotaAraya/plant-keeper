module Api
  module V1
    class InspectionPlansController < BaseController
      include EquipmentIdsParam

      before_action :set_plan, only: [ :update ]

      # GET /api/v1/inspection_plans
      # overdue=true で期限超過のみ、due_within=N で N日以内に期限が来るもの。既定は有効な計画のみ（is_active=false で無効も）
      def index
        authorize InspectionPlan
        plans = InspectionPlan.includes(:equipment, :equipments, :reference_standard, { instrument: :interlocks }, { checklist_template: :checklist_template_items })
        plans = plans.where(is_active: params[:is_active] == "false" ? false : true)
        if (site_ids = id_list_param(:site_ids, :site_id))
          plans = plans.for_sites(site_ids)
        end
        if (equipment_ids = id_list_param(:equipment_ids, :equipment_id))
          # まとめた設備のどれかに当てはまればよい（代表の設備でなくても）
          plans = plans.where(id: InspectionPlanEquipment.where(equipment_id: equipment_ids).select(:inspection_plan_id))
        end
        plans = plans.overdue if params[:overdue] == "true"
        plans = plans.due_within(params[:due_within].to_i) if params[:due_within].present?

        plans = plans.order(:next_due_on, :id)

        # 周期の見直しの候補（interval_review=extend|shorten|any）で絞るときは、候補を求めてから数える（ルールがRubyのため）
        if (review = params[:interval_review]).present?
          reviewed = plans.to_a.filter_map { |plan| [ plan, CalibrationIntervalReview.new(plan).result ] }
                          .select { |_plan, result| result && (review == "any" || result["kind"] == review) }
          page, per_page = pagination_params
          rows = reviewed.slice((page - 1) * per_page, per_page) || []
          render json: { data: rows.map { |plan, result| plan_json(plan, review: result) }, meta: { total_count: reviewed.size, page: page, per_page: per_page } }
          return
        end

        total_count = plans.count
        page, per_page = pagination_params
        plans = plans.limit(per_page).offset((page - 1) * per_page)

        render json: { data: plans.map { |plan| plan_json(plan) }, meta: { total_count: total_count, page: page, per_page: per_page } }
      end

      # POST /api/v1/inspection_plans
      def create
        plan = InspectionPlan.new(plan_params)
        authorize plan
        apply_equipment_ids(plan, :inspection_plan)
        if plan.save
          record_audit_log("create", plan, changes: plan.saved_changes.except("updated_at", "created_at").merge(equipment_ids_changes(nil, plan)))
          render json: { data: plan_json(plan) }, status: :created
        else
          render json: { errors: plan.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/inspection_plans/:id
      def update
        authorize @plan
        equipment_ids_before = equipment_ids_of(@plan)
        @plan.assign_attributes(plan_params)
        apply_equipment_ids(@plan, :inspection_plan)
        if @plan.save
          record_audit_log("update", @plan, changes: @plan.saved_changes.except("updated_at", "created_at").merge(equipment_ids_changes(equipment_ids_before, @plan)))
          render json: { data: plan_json(@plan) }
        else
          render json: { errors: @plan.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_plan
        @plan = InspectionPlan.find(params[:id])
      end

      # interval_review は、5点校正のある計画の周期の見直しの候補（なければ nil）
      def plan_json(plan, review: :compute)
        review = CalibrationIntervalReview.new(plan).result if review == :compute
        plan.as_json(
          methods: [ :overdue, :days_until_due ],
          include: {
            equipment: { only: [ :id, :name, :site_id ] },
            equipments: { only: [ :id, :name, :site_id ] },
            reference_standard: { only: [ :id, :name, :management_number, :site_id ] },
            instrument: { only: [ :id, :tag_number ] },
            checklist_template: { only: [ :id, :name ] }
          }
        ).merge("interval_review" => review)
      end

      def plan_params
        params.require(:inspection_plan).permit(
          :name, :equipment_id, :reference_standard_id, :instrument_id, :checklist_template_id, :inspection_type,
          :interval_days, :next_due_on, :is_active
        )
      end
    end
  end
end
