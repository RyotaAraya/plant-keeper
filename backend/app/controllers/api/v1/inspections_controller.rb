module Api
  module V1
    class InspectionsController < BaseController
      before_action :set_inspection, only: [ :show, :update ]

      # GET /api/v1/inspections
      def index
        inspections = Inspection.includes(:user, :equipment, :department, :checklist_template).all
        inspections = inspections.where(equipment_id: params[:equipment_id]) if params[:equipment_id].present?
        inspections = inspections.where(instrument_id: params[:instrument_id]) if params[:instrument_id].present?
        inspections = inspections.where(department_id: params[:department_id]) if params[:department_id].present?
        inspections = inspections.where(inspection_type: params[:inspection_type]) if params[:inspection_type].present?
        inspections = inspections.where(status: params[:status]) if params[:status].present?

        inspections = inspections.order(inspected_at: :desc)
        total_count = inspections.count

        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        inspections = inspections.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: inspections.as_json(
            include: {
              user: { only: [ :id, :name ] },
              equipment: { only: [ :id, :name ] },
              department: { only: [ :id, :name ] },
              checklist_template: { only: [ :id, :name ] }
            }
          ),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/inspections/:id
      def show
        render json: {
          data: @inspection.as_json(
            include: {
              user: { only: [ :id, :name ] },
              equipment: { only: [ :id, :name ] },
              department: { only: [ :id, :name ] },
              instrument: { only: [ :id, :tag_number ] },
              checklist_template: { only: [ :id, :name ] },
              inspection_items: {
                include: {
                  trouble: { only: [ :id, :title, :status ] },
                  instrument: { only: [ :id, :tag_number ] }
                }
              }
            }
          )
        }
      end

      # POST /api/v1/inspections
      def create
        inspection = Inspection.new(inspection_params)
        authorize inspection
        inspection.user = current_user

        ActiveRecord::Base.transaction do
          inspection.save!

          if params[:inspection][:items].present?
            params[:inspection][:items].each_with_index do |item, idx|
              ii = inspection.inspection_items.create!(
                checklist_template_item_id: item[:checklist_template_item_id],
                position: idx + 1,
                content: item[:content],
                item_type: item[:item_type] || "check",
                checked: item[:checked] || false,
                measured_value: item[:measured_value],
                text_value: item[:text_value],
                has_defect: item[:has_defect] || false,
                instrument_id: item[:instrument_id]
              )

              # 不具合→トラブル自動作成
              if item[:has_defect] && item[:defect_title].present?
                Trouble.create!(
                  inspection_item: ii,
                  equipment_id: inspection.equipment_id,
                  instrument_id: item[:instrument_id] || inspection.instrument_id,
                  reported_by: current_user,
                  title: item[:defect_title],
                  description: item[:defect_description],
                  status: "open",
                  priority: item[:defect_priority] || "medium",
                  reported_at: Time.current
                )
              end
            end
          end
        end

        inspection.reload
        render json: {
          data: inspection.as_json(include: { inspection_items: { include: { trouble: { only: [ :id, :title ] } } } })
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      end

      # PATCH /api/v1/inspections/:id
      def update
        authorize @inspection
        ActiveRecord::Base.transaction do
          @inspection.update!(inspection_params)

          if params[:inspection][:items].present?
            existing_ids = params[:inspection][:items].filter_map { |i| i[:id] }
            @inspection.inspection_items.where.not(id: existing_ids).destroy_all

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
                  instrument_id: item[:instrument_id]
                )
              else
                ii = @inspection.inspection_items.create!(
                  checklist_template_item_id: item[:checklist_template_item_id],
                  position: idx + 1,
                  content: item[:content],
                  item_type: item[:item_type] || "check",
                  checked: item[:checked] || false,
                  measured_value: item[:measured_value],
                  text_value: item[:text_value],
                  has_defect: item[:has_defect] || false,
                  instrument_id: item[:instrument_id]
                )
              end

              # 不具合→トラブル自動作成（新規の不具合のみ）
              if item[:has_defect] && item[:defect_title].present? && ii.trouble.nil?
                Trouble.create!(
                  inspection_item: ii,
                  equipment_id: @inspection.equipment_id,
                  instrument_id: item[:instrument_id] || @inspection.instrument_id,
                  reported_by: current_user,
                  title: item[:defect_title],
                  description: item[:defect_description],
                  status: "open",
                  priority: item[:defect_priority] || "medium",
                  reported_at: Time.current
                )
              end
            end
          end
        end

        @inspection.reload
        render json: {
          data: @inspection.as_json(include: { inspection_items: { include: { trouble: { only: [ :id, :title ] } } } })
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      end

      private

      def set_inspection
        @inspection = Inspection.includes(
          :user, :equipment, :department, :instrument, :checklist_template,
          inspection_items: [ :trouble, :instrument ]
        ).find(params[:id])
      end

      def inspection_params
        params.require(:inspection).permit(
          :checklist_template_id, :equipment_id, :instrument_id,
          :department_id, :inspection_type, :status, :inspected_at, :notes
        )
      end
    end
  end
end
