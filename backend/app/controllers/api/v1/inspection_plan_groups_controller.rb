module Api
  module V1
    # 点検のまとまり（点検計画の親）。担当部署・法規区分・既定の周期を持ち、周期と次回期限は子の点検計画が持つ
    class InspectionPlanGroupsController < BaseController
      before_action :set_group, only: [ :show, :update ]

      GROUP_INCLUDE = {
        site: { only: [ :id, :name ] },
        department: { only: [ :id, :name ] },
        regulation: { only: [ :id, :code, :name ] }
      }.freeze

      # GET /api/v1/inspection_plan_groups
      # 既定は有効なまとまりのみ（is_active=false で無効も）。plans_count は有効な計画の数
      def index
        authorize InspectionPlanGroup
        groups = InspectionPlanGroup.includes(:site, :department, :regulation).order(:site_id, :name)
        groups = groups.active unless params[:is_active] == "false"
        groups = groups.where(site_id: id_list_param(:site_ids, :site_id)) if id_list_param(:site_ids, :site_id)
        counts = InspectionPlan.active.where(inspection_plan_group_id: groups.select(:id)).group(:inspection_plan_group_id).count
        render json: { data: groups.map { |group| group_json(group).merge("plans_count" => counts[group.id] || 0) } }
      end

      # GET /api/v1/inspection_plan_groups/:id（子の点検計画つき。無効の計画も含む）
      def show
        authorize @group
        plans = @group.inspection_plans.includes(:equipment, :reference_standard, :instrument, :checklist_template).order(:next_due_on, :id)
        render json: {
          data: group_json(@group).merge(
            "inspection_plans" => plans.as_json(
              only: [ :id, :name, :interval_days, :last_inspected_on, :next_due_on, :is_active ],
              include: {
                equipment: { only: [ :id, :name ] },
                reference_standard: { only: [ :id, :name ] },
                instrument: { only: [ :id, :tag_number ] },
                checklist_template: { only: [ :id, :name ] }
              }
            )
          )
        }
      end

      # POST /api/v1/inspection_plan_groups
      def create
        group = InspectionPlanGroup.new(group_params)
        authorize group
        if group.save
          record_audit_log("create", group)
          render json: { data: group_json(group) }, status: :created
        else
          render json: { errors: group.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/inspection_plan_groups/:id（拠点は変えられない。子の計画の拠点と合わなくなるため）
      def update
        authorize @group
        if @group.update(group_params.except(:site_id))
          record_audit_log("update", @group)
          render json: { data: group_json(@group) }
        else
          render json: { errors: @group.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_group
        @group = InspectionPlanGroup.find(params[:id])
      end

      def group_json(group) = group.as_json(include: GROUP_INCLUDE)

      def group_params
        params.require(:inspection_plan_group).permit(:site_id, :name, :department_id, :regulation_id, :default_interval_days, :is_active)
      end
    end
  end
end
