module Api
  module V1
    class InspectionsController < BaseController
      before_action :set_inspection, only: [ :show, :update ]

      # 使った基準器（点検日に効いていた校正つき）
      REFERENCE_STANDARD_INCLUDE = {
        methods: [ :calibration_at_inspection ],
        include: { reference_standard: { only: [ :id, :management_number, :name, :category, :status ] } }
      }.freeze

      # GET /api/v1/inspections
      def index
        authorize Inspection
        inspections = Inspection.includes(:user, :equipment, :equipments, :instrument, :department, :checklist_template).all
        # 拠点は代表の設備の拠点で絞る（まとめて点検した設備は同じ拠点。点検の部署は入力時に選ぶ値で、拠点の決め手にならない）
        if (site_ids = id_list_param(:site_ids, :site_id))
          inspections = inspections.where(equipment_id: Equipment.where(site_id: site_ids).select(:id))
        end
        if (equipment_ids = id_list_param(:equipment_ids, :equipment_id))
          # まとめて点検した設備のどれかに当てはまればよい（代表の設備でなくても）
          inspections = inspections.where(id: InspectionEquipment.where(equipment_id: equipment_ids).select(:inspection_id))
        end
        inspections = inspections.where(instrument_id: params[:instrument_id]) if params[:instrument_id].present?
        inspections = inspections.where(department_id: params[:department_id]) if params[:department_id].present?
        if (types = value_list_param(:inspection_types, :inspection_type))
          inspections = inspections.where(inspection_type: types)
        end
        if (statuses = value_list_param(:statuses, :status))
          inspections = inspections.where(status: statuses)
        end

        inspections = inspections.order(inspected_at: :desc)
        total_count = inspections.count

        page, per_page = pagination_params
        inspections = inspections.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: inspections.as_json(
            include: {
              user: { only: [ :id, :name ] },
              equipment: { only: [ :id, :name ] },
              equipments: { only: [ :id, :name ] },
              instrument: { only: [ :id, :tag_number ] },
              department: { only: [ :id, :name ] },
              checklist_template: { only: [ :id, :name ] }
            }
          ),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/inspections/:id
      def show
        authorize @inspection
        render json: {
          data: @inspection.as_json(
            include: {
              user: { only: [ :id, :name ] },
              equipment: { only: [ :id, :name ] },
              equipments: { only: [ :id, :name ] },
              department: { only: [ :id, :name ] },
              instrument: { only: [ :id, :tag_number ] },
              checklist_template: { only: [ :id, :name ] },
              maintenance_task: { only: [ :id, :title, :scheduled_maintenance_id ] },
              inspection_items: {
                include: {
                  trouble: { only: [ :id, :title, :status ] },
                  instrument: { only: [ :id, :tag_number ] },
                  equipment: { only: [ :id, :name ] }
                }
              },
              inspection_reference_standards: REFERENCE_STANDARD_INCLUDE
            }
          )
        }
      end

      # POST /api/v1/inspections
      def create
        inspection = Inspection.new(inspection_params)
        authorize inspection
        inspection.user = current_user
        apply_equipment_ids(inspection)

        # 承認フローを飛び越えた状態での新規作成は不可（下書き・提出済のみ）
        unless %w[draft submitted].include?(inspection.status)
          return render json: { errors: [ "新規作成できるのは下書きまたは提出済のみです" ] }, status: :unprocessable_entity
        end

        ActiveRecord::Base.transaction do
          inspection.save!
          record_audit_log("create", inspection, changes: inspection.saved_changes.except("updated_at", "created_at").merge(equipment_ids_changes(nil, inspection)))

          if params[:inspection][:items].present?
            params[:inspection][:items].each_with_index do |item, idx|
              create_item!(inspection, item, idx)
            end
          end
          sync_reference_standards!(inspection)
          inspection.check_reference_standards! unless inspection.draft?
        end

        inspection.reload
        render json: {
          data: inspection.as_json(include: { equipments: { only: [ :id, :name ] }, inspection_items: { include: { trouble: { only: [ :id, :title ] } } } })
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      rescue Inspection::UnusableReferenceStandards => e
        render json: { errors: e.problems }, status: :unprocessable_entity
      end

      # PATCH /api/v1/inspections/:id
      def update
        authorize @inspection
        equipment_ids_before = @inspection.inspection_equipments.pluck(:equipment_id).sort
        @inspection.assign_attributes(inspection_params)
        apply_equipment_ids(@inspection)
        # 承認と差し戻し（承認依頼中から出る操作）は承認者のみ。作成者本人でも自分で差し戻せない
        if @inspection.status_changed? && (@inspection.approved? || @inspection.status_was == "approval_requested")
          authorize @inspection, :approve?
        end

        if content_edit_while_approval_requested?
          return render json: { errors: [ "承認依頼中の点検は内容を編集できません。差し戻してから編集してください" ] },
                        status: :unprocessable_entity
        end

        ActiveRecord::Base.transaction do
          approval_requested = @inspection.status_changed?(to: "approval_requested")
          leaving_draft = @inspection.status_was == "draft" && !@inspection.draft?
          @inspection.save!
          record_audit_log(approval_requested ? "approval_request" : "update", @inspection,
                           changes: @inspection.saved_changes.except("updated_at", "created_at").merge(equipment_ids_changes(equipment_ids_before, @inspection)))

          if params[:inspection][:items].present?
            existing_ids = params[:inspection][:items].filter_map { |i| i[:id] }
            @inspection.inspection_items.where.not(id: existing_ids).each do |removed|
              removed.destroy!
              record_audit_log("delete", removed, changes: removed.attributes.except("created_at", "updated_at"))
            end

            params[:inspection][:items].each_with_index do |item, idx|
              if item[:id]
                ii = @inspection.inspection_items.find(item[:id])
                ii.update!(
                  position: idx + 1,
                  content: item[:content],
                  item_type: item[:item_type],
                  checked: item[:checked],
                  measured_value: item[:measured_value],
                  text_value: item[:text_value],
                  has_defect: item[:has_defect],
                  instrument_id: item[:instrument_id],
                  equipment_id: item[:equipment_id].presence,
                  calibration_input: calibration_input_for(item)
                )
                record_audit_log("update", ii) if ii.saved_changes.except("updated_at").any?
                create_trouble_for_defect!(@inspection, ii, item)
              else
                create_item!(@inspection, item, idx)
              end
            end
          end
          sync_reference_standards!(@inspection)
          # 下書きを出るとき、または提出後に基準器を変えたときに、使った基準器が点検日に使えるかを確認する
          @inspection.check_reference_standards! if !@inspection.draft? && (leaving_draft || params[:inspection].key?(:reference_standards))
        end

        @inspection.reload
        render json: {
          data: @inspection.as_json(include: { equipments: { only: [ :id, :name ] }, inspection_items: { include: { trouble: { only: [ :id, :title ] } } } })
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      rescue Inspection::UnusableReferenceStandards => e
        render json: { errors: e.problems }, status: :unprocessable_entity
      end

      private

      # 承認依頼中は承認者が見ている内容が変わらないよう、内容の編集を止める（状態変更は可）
      def content_edit_while_approval_requested?
        @inspection.status_was == "approval_requested" &&
          ((@inspection.changed - [ "status" ]).any? || params[:inspection].key?(:items) || params[:inspection].key?(:reference_standards) ||
           equipment_ids_changed?)
      end

      def equipment_ids_changed?
        ids = equipment_ids_param
        ids.present? && ids.sort != @inspection.inspection_equipments.pluck(:equipment_id).sort
      end

      # 点検で見た設備。equipment_ids が送られたら、先頭を代表の設備にする（送られなければ equipment_id のまま）
      def equipment_ids_param
        return unless params[:inspection].key?(:equipment_ids)

        Array(params[:inspection][:equipment_ids]).map(&:to_i).select(&:positive?).uniq.presence
      end

      def apply_equipment_ids(inspection)
        return unless (ids = equipment_ids_param)

        inspection.equipment_id = ids.first
        inspection.equipment_ids_input = ids
      end

      # 監査ログの変更内容。設備が2つ以上、または変わったときだけ、点検で見た設備のIDを [前, 後] で残す
      def equipment_ids_changes(before, inspection)
        after = inspection.inspection_equipments.reload.pluck(:equipment_id).sort
        return {} if before.nil? ? after.size < 2 : before == after

        { "equipment_ids" => [ before, after ] }
      end

      # 使った基準器と使用前の1点チェック。reference_standards が送られたときだけ、送られた内容に合わせる（無ければ変えない）
      def sync_reference_standards!(inspection)
        return unless params[:inspection].key?(:reference_standards)

        uses = Array(params[:inspection][:reference_standards]).select { |use| use.respond_to?(:key?) }
        ids = uses.filter_map { |use| use[:reference_standard_id].presence&.to_i }
        inspection.inspection_reference_standards.where.not(reference_standard_id: ids).destroy_all
        uses.each do |use|
          link = inspection.inspection_reference_standards.find_or_initialize_by(reference_standard_id: use[:reference_standard_id])
          link.update!(pre_check_passed: ActiveModel::Type::Boolean.new.cast(use[:pre_check_passed]), pre_check_note: use[:pre_check_note])
        end
        inspection.inspection_reference_standards.reset
      end

      def create_item!(inspection, item, idx)
        ii = inspection.inspection_items.create!(
          checklist_template_item_id: item[:checklist_template_item_id],
          position: idx + 1,
          content: item[:content],
          item_type: item[:item_type] || "check",
          checked: item[:checked] || false,
          measured_value: item[:measured_value],
          text_value: item[:text_value],
          has_defect: item[:has_defect] || false,
          instrument_id: item[:instrument_id],
          equipment_id: item[:equipment_id].presence,
          calibration_input: calibration_input_for(item)
        )
        record_audit_log("create", ii)
        create_trouble_for_defect!(inspection, ii, item)
        ii
      end

      # 5点校正の項目の入力（送られていなければ nil で、記録は変えない）
      def calibration_input_for(item)
        item[:calibration] if item[:item_type] == "calibration"
      end

      # 不具合→トラブル自動作成（不具合タイトルがあり、まだトラブルが無い項目のみ）
      def create_trouble_for_defect!(inspection, ii, item)
        return unless item[:has_defect] && item[:defect_title].present? && ii.trouble.nil?

        # 複数の設備をまとめて点検したときは、不具合の項目の設備（なければ代表の設備）のトラブルにする。
        # 点検の計器は代表の設備のものなので、別の設備のトラブルには引き継がない
        equipment_id = ii.equipment_id || inspection.equipment_id
        trouble = Trouble.create!(
          inspection_item: ii,
          equipment_id: equipment_id,
          instrument_id: item[:instrument_id] || (inspection.instrument_id if equipment_id == inspection.equipment_id),
          reported_by: current_user,
          title: item[:defect_title],
          description: item[:defect_description],
          status: "open",
          priority: item[:defect_priority] || "medium",
          reported_at: Time.current
        )
        # AIの下書きをもとにしたときは、その提案のIDを残す（AIの案と、人が確定した内容を突き合わせられるように）
        changes = trouble.saved_changes.except("updated_at", "created_at")
        suggestion_id = ai_suggestion_id_for(trouble, item[:ai_suggestion_id])
        changes = changes.merge("ai_suggestion_id" => suggestion_id) if suggestion_id
        record_audit_log("create", trouble, changes: changes)
      end

      # 画面から送られた提案のIDのうち、本人が今回の設備・計器について作った成功済みの提案だけを認める。
      # 一致しないものは黙って無視する（設備を変えたあとに送られても、点検の保存を止めない）
      def ai_suggestion_id_for(trouble, id)
        return if id.blank?

        suggestion = AiSuggestion.find_by(id: id, user_id: current_user.id, kind: "defect_draft", status: "succeeded", equipment_id: trouble.equipment_id)
        return unless suggestion
        return if suggestion.instrument_id && suggestion.instrument_id != trouble.instrument_id

        suggestion.id
      end

      def set_inspection
        @inspection = Inspection.includes(
          :user, :equipment, :department, :instrument, :checklist_template, :maintenance_task,
          inspection_items: [ :trouble, :instrument ],
          inspection_reference_standards: :reference_standard
        ).find(params[:id])
      end

      def inspection_params
        params.require(:inspection).permit(
          :checklist_template_id, :inspection_plan_id, :maintenance_task_id, :equipment_id, :instrument_id,
          :department_id, :inspection_type, :status, :inspected_at, :notes
        )
      end
    end
  end
end
