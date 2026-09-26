module Api
  module V1
    # インターロックの台帳（関係する計器と、終わっていないバイパス）
    class InterlocksController < BaseController
      include InterlockBypassJson

      before_action :set_interlock, only: [ :show, :update ]

      # GET /api/v1/interlocks
      # bypass_state: overdue=復帰期限超過 / bypassed=バイパス中 / restored=復帰確認待ち / requested=承認待ち / open=終わっていないバイパスあり / none=なし
      def index
        authorize Interlock
        interlocks = Interlock.includes(:instruments, equipment: :site).joins(:equipment)
        interlocks = interlocks.where(equipments: { site_id: id_list_param(:site_ids, :site_id) }) if id_list_param(:site_ids, :site_id)
        interlocks = interlocks.where(equipment_id: params[:equipment_id]) if params[:equipment_id].present?
        interlocks = interlocks.where(id: InterlockInstrument.where(instrument_id: params[:instrument_id]).select(:interlock_id)) if params[:instrument_id].present?
        interlocks = interlocks.active unless params[:include_inactive] == "true"
        if params[:q].present?
          q = "%#{params[:q]}%"
          # 関係する計器のタグ番号でも探せる
          tagged = InterlockInstrument.joins(:instrument).where("instruments.tag_number ILIKE ?", q).select(:interlock_id)
          interlocks = interlocks.where("interlocks.tag_number ILIKE :q OR interlocks.name ILIKE :q", q: q).or(interlocks.where(id: tagged))
        end
        interlocks = filter_by_bypass_state(interlocks, params[:bypass_state]) if params[:bypass_state].present?

        interlocks = interlocks.order("equipments.site_id", "equipments.name", :tag_number)
        total_count = interlocks.count
        page, per_page = pagination_params(default_per_page: 100)
        interlocks = interlocks.limit(per_page).offset((page - 1) * per_page).to_a
        open_bypasses = InterlockBypass.open.where(interlock_id: interlocks.map(&:id)).includes(*BYPASS_INCLUDES).index_by(&:interlock_id)

        render json: { data: interlocks.map { |interlock| interlock_json(interlock, open_bypasses[interlock.id]) },
                       meta: { total_count: total_count, page: page, per_page: per_page } }
      end

      # GET /api/v1/interlocks/:id
      def show
        authorize @interlock
        bypasses = @interlock.bypasses.includes(*BYPASS_INCLUDES)
        render json: { data: interlock_json(@interlock, bypasses.detect(&:open?)).merge(
          "bypasses" => bypasses.map { |bypass| bypass_json(bypass) }
        ) }
      end

      # POST /api/v1/interlocks
      def create
        interlock = Interlock.new(interlock_params.merge(params.require(:interlock).permit(:equipment_id)))
        authorize interlock
        save_interlock(interlock, "create", :created)
      end

      # PATCH /api/v1/interlocks/:id
      def update
        authorize @interlock
        @interlock.assign_attributes(interlock_params)
        save_interlock(@interlock, "update", :ok)
      end

      private

      def set_interlock
        @interlock = Interlock.includes(:instruments, equipment: :site).find(params[:id])
      end

      def save_interlock(interlock, action, status)
        ActiveRecord::Base.transaction do
          instrument_ids_before = interlock.instrument_ids
          interlock.instruments = Instrument.where(id: params[:interlock][:instrument_ids]) if params[:interlock]&.key?(:instrument_ids)
          interlock.save!
          changes = interlock.saved_changes.except("updated_at", "created_at")
          changes["instrument_ids"] = [ instrument_ids_before, interlock.instrument_ids ] if instrument_ids_before.sort != interlock.instrument_ids.sort
          record_audit_log(action, interlock, changes: changes)
        end
        render json: { data: interlock_json(interlock.reload, interlock.open_bypass) }, status: status
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def interlock_json(interlock, open_bypass)
        interlock.as_json(except: [ :created_at, :updated_at ]).merge(
          "equipment" => { "id" => interlock.equipment.id, "name" => interlock.equipment.name, "site" => interlock.equipment.site.as_json(only: [ :id, :name ]) },
          "instruments" => interlock.instruments.sort_by(&:tag_number).map { |instrument| instrument.as_json(only: [ :id, :tag_number, :instrument_type ]) },
          "open_bypass" => open_bypass && bypass_json(open_bypass)
        )
      end

      def filter_by_bypass_state(interlocks, state)
        case state
        when "bypassed" then interlocks.where(id: InterlockBypass.status_bypassed.select(:interlock_id))
        when "restored" then interlocks.where(id: InterlockBypass.status_restored.select(:interlock_id))
        when "requested" then interlocks.where(id: InterlockBypass.status_requested.select(:interlock_id))
        when "overdue" then interlocks.where(id: InterlockBypass.overdue.select(:interlock_id))
        when "open" then interlocks.where(id: InterlockBypass.open.select(:interlock_id))
        when "none" then interlocks.where.not(id: InterlockBypass.open.select(:interlock_id))
        else interlocks
        end
      end

      # 設備は登録のときだけ（あとから変えると、関係する計器やバイパスの記録と設備が食い違うため）
      def interlock_params
        params.require(:interlock).permit(:tag_number, :name, :trip_action, :notes, :is_active)
      end
    end
  end
end
