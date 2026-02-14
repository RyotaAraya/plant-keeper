module Api
  module V1
    class ChecklistTemplatesController < BaseController
      before_action :set_template, only: [:show, :update, :destroy, :duplicate]

      # GET /api/v1/checklist_templates
      def index
        templates = ChecklistTemplate.includes(:department, :checklist_template_items).all
        templates = templates.where(department_id: params[:department_id]) if params[:department_id].present?
        templates = templates.where(inspection_type: params[:inspection_type]) if params[:inspection_type].present?

        render json: {
          data: templates.as_json(
            include: {
              department: { only: [:id, :name] },
              checklist_template_items: { only: [:id, :position, :content, :item_type] }
            }
          )
        }
      end

      # GET /api/v1/checklist_templates/:id
      def show
        render json: {
          data: @template.as_json(
            include: {
              department: { only: [:id, :name] },
              checklist_template_items: { only: [:id, :position, :content, :item_type] }
            }
          )
        }
      end

      # POST /api/v1/checklist_templates
      def create
        template = ChecklistTemplate.new(template_params)

        if template.save
          if params[:checklist_template][:items].present?
            params[:checklist_template][:items].each_with_index do |item, idx|
              template.checklist_template_items.create!(
                position: idx + 1,
                content: item[:content],
                item_type: item[:item_type] || 'check'
              )
            end
          end
          render json: { data: template.as_json(include: { checklist_template_items: {} }) }, status: :created
        else
          render json: { errors: template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/checklist_templates/:id
      def update
        ActiveRecord::Base.transaction do
          @template.update!(template_params)

          if params[:checklist_template][:items].present?
            existing_ids = params[:checklist_template][:items].filter_map { |i| i[:id] }
            @template.checklist_template_items.where.not(id: existing_ids).destroy_all

            params[:checklist_template][:items].each_with_index do |item, idx|
              if item[:id]
                ci = @template.checklist_template_items.find(item[:id])
                ci.update!(position: idx + 1, content: item[:content], item_type: item[:item_type])
              else
                @template.checklist_template_items.create!(
                  position: idx + 1,
                  content: item[:content],
                  item_type: item[:item_type] || 'check'
                )
              end
            end
          end
        end

        @template.reload
        render json: {
          data: @template.as_json(include: { checklist_template_items: {} })
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [e.message] }, status: :unprocessable_entity
      end

      # DELETE /api/v1/checklist_templates/:id
      def destroy
        if @template.destroy
          head :no_content
        else
          render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/checklist_templates/:id/duplicate
      def duplicate
        new_template = @template.dup
        new_template.name = "#{@template.name}（コピー）"

        ActiveRecord::Base.transaction do
          new_template.save!
          @template.checklist_template_items.each do |item|
            new_template.checklist_template_items.create!(
              position: item.position,
              content: item.content,
              item_type: item.item_type
            )
          end
        end

        render json: {
          data: new_template.as_json(include: { checklist_template_items: {} })
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [e.message] }, status: :unprocessable_entity
      end

      private

      def set_template
        @template = ChecklistTemplate.includes(:department, :checklist_template_items).find(params[:id])
      end

      def template_params
        params.require(:checklist_template).permit(:name, :department_id, :inspection_type)
      end
    end
  end
end
