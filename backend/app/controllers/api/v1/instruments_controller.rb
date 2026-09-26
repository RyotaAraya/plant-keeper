module Api
  module V1
    class InstrumentsController < BaseController
      before_action :set_instrument, only: [ :show, :update ]

      def index
        authorize Instrument
        instruments = Instrument.includes(:equipment, :service, :line_class)

        # 拠点・設備フィルタ（複数対応）
        if (site_ids = id_list_param(:site_ids, :site_id))
          instruments = instruments.joins(:equipment).where(equipments: { site_id: site_ids })
        end
        if (equipment_ids = id_list_param(:equipment_ids, :equipment_id))
          instruments = instruments.where(equipment_id: equipment_ids)
        end

        # サービスフィルタ（複数対応）
        if params[:service_ids].present?
          ids = Array(params[:service_ids]).map(&:to_i).select(&:positive?)
          instruments = instruments.where(service_id: ids) if ids.any?
        elsif params[:service_id].present?
          instruments = instruments.where(service_id: params[:service_id])
        end

        # ラインクラスフィルタ（複数対応）
        if params[:line_class_ids].present?
          ids = Array(params[:line_class_ids]).map(&:to_i).select(&:positive?)
          instruments = instruments.where(line_class_id: ids) if ids.any?
        elsif params[:line_class_id].present?
          instruments = instruments.where(line_class_id: params[:line_class_id])
        end

        if params[:q].present?
          q = "%#{params[:q]}%"
          instruments = instruments.where("tag_number ILIKE ? OR instrument_type ILIKE ? OR location ILIKE ?", q, q, q)
        end

        instruments = instruments.order(:tag_number)
        total_count = instruments.count

        page, per_page = pagination_params
        instruments = instruments.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: instruments.as_json(
            methods: [ :calibration_kind, :calibratable, :troubleshooting_checks ],
            include: {
              equipment: { only: [ :id, :name ] },
              service: { only: [ :id, :name ] },
              line_class: { only: [ :id, :code ] }
            }
          ),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      def show
        authorize @instrument
        render json: {
          data: @instrument.as_json(
            methods: [ :calibration_kind, :calibratable, :troubleshooting_checks ],
            include: {
              equipment: { only: [ :id, :name ], include: { site: { only: [ :id, :name ] } } },
              service: {},
              line_class: {}
            }
          ).merge("calibration_history" => CalibrationTrend.new(@instrument).rows)
        }
      end

      def create
        instrument = Instrument.new(instrument_params)
        authorize instrument
        if instrument.save
          record_audit_log("create", instrument)
          render json: { data: instrument.as_json }, status: :created
        else
          render json: { errors: instrument.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        authorize @instrument
        if @instrument.update(instrument_params)
          record_audit_log("update", @instrument)
          render json: { data: @instrument.as_json }
        else
          render json: { errors: @instrument.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_instrument
        @instrument = Instrument.includes(:equipment, :service, :line_class).find(params[:id])
      end

      def instrument_params
        params.require(:instrument).permit(
          :equipment_id, :tag_number, :instrument_type, :service_id, :line_class_id, :location, :notes,
          :seal_fluid,
          :range_lower, :range_upper, :range_unit, :output_characteristic, :dcs_characteristic,
          :dcs_range_lower, :dcs_range_upper, :dcs_range_unit, :tolerance_percent, :tolerance_basis,
          :telemetry, :custody_transfer
        )
      end
    end
  end
end
