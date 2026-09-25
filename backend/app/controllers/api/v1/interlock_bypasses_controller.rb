module Api
  module V1
    # インターロックのバイパス（申請・承認・却下・実施・復帰・復帰確認・取消）。状態を変えるたびに監査ログに残す
    class InterlockBypassesController < BaseController
      include InterlockBypassJson

      before_action :set_bypass, only: [ :show, :approve, :reject, :start, :restore, :confirm, :cancel ]

      # GET /api/v1/interlock_bypasses
      # scope: open=終わっていないもの（既定） / all。overdue=true で復帰期限超過だけ
      def index
        authorize InterlockBypass
        bypasses = InterlockBypass.includes(*BYPASS_INCLUDES)
        bypasses = bypasses.for_sites(id_list_param(:site_ids, :site_id)) if id_list_param(:site_ids, :site_id)
        bypasses = bypasses.where(interlock_id: params[:interlock_id]) if params[:interlock_id].present?
        bypasses = bypasses.open unless params[:scope] == "all"
        if (statuses = value_list_param(:statuses, :status))
          bypasses = bypasses.where(status: statuses)
        end
        bypasses = bypasses.overdue if params[:overdue] == "true"

        # 復帰期限超過 → バイパス中（予定の復帰が近い順） → それ以外（新しい順）
        bypasses = bypasses.order(Arel.sql("CASE interlock_bypasses.status WHEN 'bypassed' THEN 0 WHEN 'restored' THEN 1 WHEN 'approved' THEN 2 WHEN 'requested' THEN 3 ELSE 4 END"),
                                  :planned_restore_at, requested_at: :desc)
        total_count = bypasses.count
        page, per_page = pagination_params(default_per_page: 100)
        bypasses = bypasses.limit(per_page).offset((page - 1) * per_page)

        render json: { data: bypasses.map { |bypass| bypass_json(bypass) }, meta: { total_count: total_count, page: page, per_page: per_page } }
      end

      # GET /api/v1/interlock_bypasses/:id
      def show
        authorize @bypass
        render json: { data: bypass_json(@bypass) }
      end

      # POST /api/v1/interlock_bypasses
      def create
        bypass = InterlockBypass.new(params.require(:interlock_bypass).permit(:interlock_id, :reason, :compensatory_measure, :planned_restore_at))
        bypass.assign_attributes(requested_by: current_user, requested_at: Time.current)
        authorize bypass
        ActiveRecord::Base.transaction do
          bypass.save!
          record_audit_log("create", bypass)
        end
        render json: { data: bypass_json(bypass) }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotUnique
        # 同じインターロックへの申請が同時に来た（検証をすり抜けて、終わっていないバイパスを1件にする一意制約に当たった）
        render json: { errors: [ "同じインターロックに、同時に別の申請がありました。画面を開き直して確認してください" ] }, status: :unprocessable_entity
      end

      # POST /api/v1/interlock_bypasses/:id/approve など
      def approve = transition { @bypass.approve!(current_user) }
      def start = transition { @bypass.start!(current_user) }
      def restore = transition { @bypass.restore!(current_user) }
      def confirm = transition { @bypass.confirm!(current_user) }
      def reject = transition { @bypass.reject!(current_user, params[:reason]) }
      def cancel = transition { @bypass.cancel!(current_user, params[:reason]) }

      private

      def set_bypass
        @bypass = InterlockBypass.includes(*BYPASS_INCLUDES).find(params[:id])
      end

      def transition
        authorize @bypass
        ActiveRecord::Base.transaction do
          @bypass.with_lock do
            yield
            record_audit_log("update", @bypass)
          end
        end
        render json: { data: bypass_json(@bypass) }
      rescue InterlockBypass::TransitionError => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
