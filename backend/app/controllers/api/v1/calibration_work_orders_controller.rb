module Api
  module V1
    # 校正の作業指示の書き出し（CalibrationWorkOrder。形式は `校正結果の取り込み形式.md`）。
    # 書き出せる計画の一覧（index）から選んだ計画を、ファイルの中身として返す（create）。書き出したことは計画ごとに監査ログに残す
    class CalibrationWorkOrdersController < BaseController
      # GET /api/v1/calibration_work_orders — 書き出せる計画（有効で5点校正がある）。期限の近い順
      def index
        authorize InspectionPlan, :index?
        plans = CalibrationWorkOrder.candidates(site_ids: site_ids)
        render json: { data: plans.map { |plan| candidate_json(plan) } }
      end

      # POST /api/v1/calibration_work_orders — inspection_plan_ids の計画を書き出す
      def create
        authorize InspectionPlan, :index?
        work_order = CalibrationWorkOrder.new(user: current_user, plan_ids: params[:inspection_plan_ids])
        file_name = work_order.file_name
        ActiveRecord::Base.transaction do
          work_order.plans.each do |plan|
            record_audit_log("export", plan, changes: { "format" => CalibrationWorkOrder::FORMAT, "file_name" => file_name })
          end
        end
        render json: { data: { file_name: file_name, document: work_order.document } }, status: :created
      rescue CalibrationWorkOrder::InvalidPlans => e
        render json: { errors: e.problems }, status: :unprocessable_entity
      end

      private

      # 協力会社は所属拠点で固定（拠点の指定は無視する）。指定なしは全拠点
      def site_ids
        return [ current_user.site_id ] if current_user.company&.contractor?

        id_list_param(:site_ids, :site_id)
      end

      def candidate_json(plan)
        {
          id: plan.id, name: plan.name, next_due_on: plan.next_due_on, overdue: plan.overdue, days_until_due: plan.days_until_due,
          last_inspected_on: plan.last_inspected_on, interval_days: plan.interval_days,
          site: { id: plan.equipment.site.id, name: plan.equipment.site.name },
          equipment: { id: plan.equipment.id, name: plan.equipment.name },
          instrument: { id: plan.instrument.id, tag_number: plan.instrument.tag_number },
          checklist_template: { id: plan.checklist_template.id, name: plan.checklist_template.name }
        }
      end
    end
  end
end
