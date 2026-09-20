module Api
  module V1
    class ReferenceStandardsController < BaseController
      before_action :set_standard, only: [ :show, :update ]

      CALIBRATION_FIELDS = [ :id, :performed_on, :performed_by, :certificate_number, :result, :traceable, :valid_until, :notes ].freeze

      # GET /api/v1/reference_standards
      def index
        authorize ReferenceStandard
        standards = ReferenceStandard.includes(:site, :calibrations)
        standards = standards.where(site_id: id_list_param(:site_ids, :site_id)) if id_list_param(:site_ids, :site_id)
        if (statuses = value_list_param(:statuses, :status))
          standards = standards.where(status: statuses)
        end
        if (categories = value_list_param(:categories, :category))
          standards = standards.where(category: categories)
        end
        if params[:q].present?
          q = "%#{params[:q]}%"
          standards = standards.where("management_number ILIKE ? OR name ILIKE ? OR serial_number ILIKE ? OR model_number ILIKE ?", q, q, q, q)
        end

        standards = standards.order(:management_number)
        total_count = standards.count
        page, per_page = pagination_params
        standards = standards.limit(per_page).offset((page - 1) * per_page)

        render json: { data: standards.map { |standard| standard_json(standard) }, meta: { total_count: total_count, page: page, per_page: per_page } }
      end

      # GET /api/v1/reference_standards/:id
      def show
        authorize @standard
        render json: { data: standard_json(@standard).merge(
          "inspections_using" => inspections_using(@standard),
          "impact" => impact(@standard),
          "inspection_plans" => @standard.inspection_plans.as_json(methods: [ :overdue, :days_until_due ])
        ) }
      end

      # POST /api/v1/reference_standards
      def create
        standard = ReferenceStandard.new(standard_params)
        authorize standard
        if standard.save
          record_audit_log("create", standard)
          render json: { data: standard_json(standard) }, status: :created
        else
          render json: { errors: standard.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/reference_standards/:id
      def update
        authorize @standard
        if @standard.update(standard_params)
          record_audit_log("update", @standard)
          render json: { data: standard_json(@standard) }
        else
          render json: { errors: @standard.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_standard
        @standard = ReferenceStandard.includes(:site, :calibrations).find(params[:id])
      end

      # 校正の履歴は新しい順。今日の校正の状態と次の校正の期限も返す
      def standard_json(standard)
        standard.as_json(include: { site: { only: [ :id, :name ] } }).merge(
          "calibration_state" => standard.calibration_state,
          "next_due_on" => standard.next_due_on,
          "calibrations" => standard.calibrations.map { |calibration| calibration.as_json(only: CALIBRATION_FIELDS) }
        )
      end

      # この基準器を使った点検（新しい順）。校正が不合格だったときの影響範囲をたどれるようにする
      def inspections_using(standard)
        standard.inspection_reference_standards.joins(:inspection).includes(inspection: [ :equipment, :instrument ])
                .order("inspections.inspected_at DESC").limit(100).map do |link|
          inspection = link.inspection
          {
            "inspection_id" => inspection.id, "inspected_at" => inspection.inspected_at, "status" => inspection.status,
            "equipment" => inspection.equipment.as_json(only: [ :id, :name ]), "instrument" => inspection.instrument.as_json(only: [ :id, :tag_number ]),
            "pre_check_passed" => link.pre_check_passed, "pre_check_note" => link.pre_check_note
          }
        end
      end

      # 最新の校正が不合格のとき、その前の合格した校正の実施日（since）以降にこの基準器を使った点検の件数。
      # 合格した校正が無ければ since は nil（使った点検すべて）
      def impact(standard)
        latest = standard.latest_calibration
        return unless latest&.result_fail?

        since = standard.calibrations.drop(1).find(&:result_pass?)&.performed_on
        uses = standard.inspection_reference_standards.joins(:inspection)
        uses = uses.where("inspections.inspected_at >= ?", since.beginning_of_day) if since
        { "since" => since, "count" => uses.count }
      end

      def standard_params
        params.require(:reference_standard).permit(
          :site_id, :management_number, :name, :category, :model_number, :serial_number,
          :measuring_range, :accuracy, :location, :status, :notes
        )
      end
    end
  end
end
