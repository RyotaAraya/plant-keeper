module Api
  module V1
    # 定期整備の系列（繰り返しのまとまり）と、設備ごとの周期
    class MaintenanceSeriesController < BaseController
      before_action :set_series, only: [ :show, :update ]

      SERIES_INCLUDE = {
        site: { only: [ :id, :name ] },
        maintenance_series_equipments: { only: [ :id, :equipment_id, :interval_months ], include: { equipment: { only: [ :id, :name ] } } }
      }.freeze

      # GET /api/v1/maintenance_series
      def index
        authorize MaintenanceSeries
        series = MaintenanceSeries.includes(:site, maintenance_series_equipments: :equipment).order(:name)
        series = series.where(site_id: id_list_param(:site_ids, :site_id)) if id_list_param(:site_ids, :site_id)
        render json: { data: series.as_json(include: SERIES_INCLUDE) }
      end

      # GET /api/v1/maintenance_series/:id（各回の定期整備の履歴つき）
      def show
        authorize @series
        render json: { data: series_json(@series) }
      end

      # POST /api/v1/maintenance_series
      def create
        series = MaintenanceSeries.new(series_params)
        authorize series

        ActiveRecord::Base.transaction do
          series.save!
          replace_intervals!(series)
          series.validate!
          record_audit_log("create", series)
        end
        render json: { data: series_json(series.reload) }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # PATCH /api/v1/maintenance_series/:id
      def update
        authorize @series
        ActiveRecord::Base.transaction do
          @series.update!(series_params)
          replace_intervals!(@series)
          @series.validate!
          record_audit_log("update", @series, changes: series_changes)
        end
        render json: { data: series_json(@series.reload) }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def set_series
        @series = MaintenanceSeries.includes(:site, maintenance_series_equipments: :equipment).find(params[:id])
      end

      def series_json(series)
        history = series.scheduled_maintenances.includes(:equipments).order(planned_start_on: :desc, id: :desc)
        series.as_json(include: SERIES_INCLUDE).merge(
          "maintenances" => history.as_json(only: [ :id, :title, :status, :planned_start_on, :planned_end_on ], include: { equipments: { only: [ :id, :name ] } })
        )
      end

      # equipment_intervals（[{ equipment_id, interval_months }]）が送られたときだけ、送られた内容に置き換える
      def replace_intervals!(series)
        intervals = params[:maintenance_series][:equipment_intervals]
        return if intervals.nil?

        @interval_change = [ series.intervals, {} ]
        series.maintenance_series_equipments.destroy_all
        intervals.each do |interval|
          series.maintenance_series_equipments.create!(equipment_id: interval[:equipment_id], interval_months: interval[:interval_months])
        end
        series.maintenance_series_equipments.reset
        series.equipments.reset
        @interval_change[1] = series.intervals
      end

      def series_changes
        changes = @series.saved_changes.except("updated_at", "created_at")
        changes["intervals"] = @interval_change if @interval_change && @interval_change[0] != @interval_change[1]
        changes
      end

      def series_params
        params.require(:maintenance_series).permit(:site_id, :name, :notes)
      end
    end
  end
end
