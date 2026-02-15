module Api
  module V1
    class InstrumentsController < BaseController
      before_action :set_instrument, only: [ :show, :update ]

      def index
        instruments = Instrument.includes(:equipment, :service, :line_class)
        instruments = instruments.where(equipment_id: params[:equipment_id]) if params[:equipment_id].present?
        instruments = instruments.where("tag_number ILIKE ?", "%#{params[:q]}%") if params[:q].present?

        instruments = instruments.order(:tag_number)
        total_count = instruments.count

        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        instruments = instruments.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: instruments.as_json(include: {
            equipment: { only: [ :id, :name ] },
            service: { only: [ :id, :name ] },
            line_class: { only: [ :id, :code ] }
          }),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      def show
        render json: {
          data: @instrument.as_json(include: {
            equipment: { only: [ :id, :name ], include: { site: { only: [ :id, :name ] } } },
            service: {},
            line_class: {}
          }).merge(
            recent_troubles: @instrument.troubles.order(reported_at: :desc).limit(5).as_json(only: [ :id, :title, :status, :priority, :reported_at ]),
            recent_inspections: @instrument.inspections.order(inspected_at: :desc).limit(5).as_json(only: [ :id, :inspection_type, :status, :inspected_at ])
          )
        }
      end

      def create
        instrument = Instrument.new(instrument_params)
        if instrument.save
          render json: { data: instrument.as_json }, status: :created
        else
          render json: { errors: instrument.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @instrument.update(instrument_params)
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
        params.require(:instrument).permit(:equipment_id, :tag_number, :instrument_type, :service_id, :line_class_id, :location, :notes)
      end
    end
  end
end
