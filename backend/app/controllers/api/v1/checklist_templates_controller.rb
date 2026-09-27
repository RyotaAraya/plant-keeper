module Api
  module V1
    class ChecklistTemplatesController < BaseController
      before_action :set_template, only: [ :show, :update, :destroy, :duplicate, :item_stats ]

      # 項目の型と基準（ChecklistCriteria）
      ITEM_FIELDS = [ :id, :position, :content, :item_type, :section, :criterion, :unit, :lower_limit, :upper_limit, :options, :required ].freeze

      # GET /api/v1/checklist_templates
      # 廃止したテンプレート（点検の選択肢から外したもの）は、include_inactive=true のときだけ含める
      def index
        authorize ChecklistTemplate
        templates = ChecklistTemplate.includes(:department, :checklist_template_items).all
        templates = templates.where(is_active: true) unless params[:include_inactive] == "true"
        templates = templates.where(department_id: params[:department_id]) if params[:department_id].present?
        templates = templates.where(inspection_type: params[:inspection_type]) if params[:inspection_type].present?

        render json: {
          data: ChecklistTemplate.in_display_order(templates).as_json(
            include: {
              department: { only: [ :id, :name ] },
              checklist_template_items: { only: ITEM_FIELDS }
            }
          )
        }
      end

      # GET /api/v1/checklist_templates/:id
      def show
        authorize @template
        render json: {
          data: @template.as_json(
            include: {
              department: { only: [ :id, :name ] },
              checklist_template_items: { only: ITEM_FIELDS }
            }
          )
        }
      end

      # GET /api/v1/checklist_templates/:id/item_stats
      # 項目ごとの実施回数・不具合の件数（項目の見直しの材料）。period=1y（既定）|3y|all、site_ids で拠点を絞る
      def item_stats
        authorize @template
        period = params[:period].presence || ChecklistItemStats::DEFAULT_PERIOD
        unless ChecklistItemStats.valid_period?(period)
          return render json: { errors: [ "期間の指定が正しくありません" ] }, status: :unprocessable_entity
        end

        render json: { data: ChecklistItemStats.new(@template, period: period, site_ids: id_list_param(:site_ids, :site_id)).result }
      end

      # POST /api/v1/checklist_templates
      def create
        template = ChecklistTemplate.new(template_params)
        authorize template

        ActiveRecord::Base.transaction do
          template.save!
          record_audit_log("create", template)

          if params[:checklist_template][:items].present?
            params[:checklist_template][:items].each_with_index do |item, idx|
              template.checklist_template_items.create!(item_params(item, idx))
            end
          end
        end

        render json: { data: template.as_json(include: { checklist_template_items: { only: ITEM_FIELDS } }) }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      end

      # PATCH /api/v1/checklist_templates/:id
      def update
        authorize @template
        ActiveRecord::Base.transaction do
          @template.update!(template_params)
          record_audit_log("update", @template)

          if params[:checklist_template][:items].present?
            existing_ids = params[:checklist_template][:items].filter_map { |i| i[:id] }
            @template.checklist_template_items.where.not(id: existing_ids).destroy_all

            params[:checklist_template][:items].each_with_index do |item, idx|
              if item[:id]
                @template.checklist_template_items.find(item[:id]).update!(item_params(item, idx))
              else
                @template.checklist_template_items.create!(item_params(item, idx))
              end
            end
          end
        end

        @template.reload
        render json: {
          data: @template.as_json(include: { checklist_template_items: { only: ITEM_FIELDS } })
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      end

      # DELETE /api/v1/checklist_templates/:id
      def destroy
        authorize @template
        if @template.destroy
          head :no_content
        else
          render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/checklist_templates/:id/duplicate
      def duplicate
        authorize @template, :duplicate?
        new_template = @template.dup
        new_template.name = "#{@template.name}（コピー）"
        new_template.is_active = true

        ActiveRecord::Base.transaction do
          new_template.save!
          @template.checklist_template_items.each do |item|
            new_template.checklist_template_items.create!(item.attributes.slice("position", "content", "item_type").merge(item.criteria))
          end
        end

        render json: {
          data: new_template.as_json(include: { checklist_template_items: { only: ITEM_FIELDS } })
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [ e.message ] }, status: :unprocessable_entity
      end

      private

      def set_template
        @template = ChecklistTemplate.includes(:department, :checklist_template_items).find(params[:id])
      end

      # 項目の型と基準。選択肢は空欄を除き、測定値以外の種別では単位・許容範囲を持たない
      def item_params(item, idx)
        attrs = item.permit(:content, :item_type, :section, :criterion, :unit, :lower_limit, :upper_limit, :required, options: []).to_h
        attrs["item_type"] = attrs["item_type"].presence || "check"
        attrs["options"] = attrs["item_type"] == "choice" ? Array(attrs["options"]).map { |o| o.to_s.strip }.reject(&:empty?) : nil
        attrs.merge!("unit" => nil, "lower_limit" => nil, "upper_limit" => nil) unless attrs["item_type"] == "measurement"
        attrs.merge("position" => idx + 1)
      end

      def template_params
        params.require(:checklist_template).permit(:name, :department_id, :inspection_type, :cycle, :is_active)
      end
    end
  end
end
