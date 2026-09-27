module Api
  module V1
    # キャリブレータ・校正管理ソフトの校正結果（JSON。形式は `校正結果の取り込み形式.md`）の取り込み。
    # 確認（preview）で記録ごとに取り込めるかと理由を返し、取り込み（create）で取り込める記録だけを点検の下書きにする。
    # create も同じ確認をやり直す（確認のあとに計器・基準器が変わっても、取り込めない記録は作らない）
    class CalibrationImportsController < BaseController
      # POST /api/v1/calibration_imports/preview
      def preview
        authorize Inspection, :create?
        import = build_import
        render json: { data: summary(import) }
      rescue CalibrationImport::InvalidFile => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      end

      # POST /api/v1/calibration_imports
      def create
        authorize Inspection, :create?
        import = build_import
        if import.importable_rows.empty?
          return render json: { errors: [ "取り込める記録がありません" ], data: summary(import) }, status: :unprocessable_entity
        end

        inspections = import.import! { |record| record_audit_log("create", record) }
        render json: {
          data: summary(import).merge(
            inspections: inspections.map { |inspection| { id: inspection.id, tag_number: inspection.instrument.tag_number } }
          )
        }, status: :created
      rescue CalibrationImport::InvalidFile => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      end

      # GET /api/v1/calibration_imports/sample — 見本のファイル（所属拠点の計器・基準器から作る）
      def sample
        authorize Inspection, :create?
        return render json: { errors: [ "所属拠点がないため、見本のファイルを作れません" ] }, status: :unprocessable_entity if current_user.site.nil?

        render json: CalibrationImport.sample_document(current_user.site)
      end

      private

      # 取り込み先の部署は、指定がなければ本人の所属部署
      def build_import
        department = params[:department_id].present? ? Department.find_by(id: params[:department_id]) : current_user.department
        CalibrationImport.new(user: current_user, department: department, file_name: params[:file_name], content: params[:content].to_s)
      end

      def summary(import)
        {
          file_name: import.file_name,
          calibrator: import.calibrator,
          importable_count: import.importable_rows.size,
          rows: import.rows.map do |row|
            {
              index: row.index, site_name: row.site_name, tag_number: row.tag_number, performed_at: row.performed_at,
              performed_by: row.performed_by, calibrator: row.calibrator,
              instrument: row.instrument && { id: row.instrument.id, tag_number: row.instrument.tag_number, equipment_name: row.instrument.equipment.name },
              reference_standards: row.reference_standards.map { |standard| { id: standard.id, management_number: standard.management_number, name: standard.name } },
              adjusted: row.input["adjusted"], result: row.result, importable: row.importable?, reasons: row.reasons
            }
          end
        }
      end
    end
  end
end
