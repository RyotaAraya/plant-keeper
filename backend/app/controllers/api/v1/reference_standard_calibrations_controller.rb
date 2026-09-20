module Api
  module V1
    # 基準器のメーカー校正の記録（実施日・メーカー・証明書番号・結果・有効期限）。記録すると、基準器の校正計画の次回期限が進む
    class ReferenceStandardCalibrationsController < BaseController
      before_action :set_standard

      # POST /api/v1/reference_standards/:reference_standard_id/calibrations
      def create
        calibration = @standard.calibrations.build(calibration_params)
        # 有効期限を省略したときは、実施日から標準の周期（1年）先
        calibration.valid_until ||= calibration.performed_on + ReferenceStandard::DEFAULT_INTERVAL_DAYS if calibration.performed_on
        authorize calibration
        save_calibration(calibration, "create", :created)
      end

      # PATCH /api/v1/reference_standards/:reference_standard_id/calibrations/:id
      def update
        calibration = @standard.calibrations.find(params[:id])
        authorize calibration
        calibration.assign_attributes(calibration_params)
        save_calibration(calibration, "update", :ok)
      end

      private

      def set_standard
        @standard = ReferenceStandard.find(params[:reference_standard_id])
      end

      def save_calibration(calibration, action, status)
        ActiveRecord::Base.transaction do
          calibration.save!
          record_audit_log(action, calibration)
        end
        render json: { data: calibration.as_json }, status: status
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def calibration_params
        params.require(:calibration).permit(:performed_on, :performed_by, :certificate_number, :result, :traceable, :valid_until, :notes)
      end
    end
  end
end
