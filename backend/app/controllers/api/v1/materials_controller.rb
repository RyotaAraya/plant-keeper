module Api
  module V1
    class MaterialsController < BaseController
      before_action :set_material, only: [ :show, :update ]

      # GET /api/v1/materials
      def index
        authorize Material
        materials = Material.includes(:manufacturer).all
        materials = materials.where(manufacturer_id: params[:manufacturer_id]) if params[:manufacturer_id].present?
        materials = materials.where(category: params[:category]) if params[:category].present?
        materials = materials.where(availability: params[:availability]) if params[:availability].present?
        # 自拠点に在庫があるか、他拠点にだけあるかで探す（在庫を見られる人だけ）
        materials = filter_by_stock_availability(materials, params[:stock_availability]) if params[:stock_availability].present? && can_view_stocks?

        if params[:q].present?
          q = "%#{params[:q]}%"
          normalized = params[:q].gsub(/[-\s]/, "")
          materials = materials.where(
            "name ILIKE ? OR part_number ILIKE ? OR normalized_part_number ILIKE ?",
            q, q, "%#{normalized}%"
          )
        end

        materials = materials.order(:name)
        total_count = materials.count

        page, per_page = pagination_params
        materials = materials.limit(per_page).offset((page - 1) * per_page)

        data = materials.as_json(include: { manufacturer: { only: [ :id, :name ] } })
        # 拠点別の使える在庫。在庫を見られない人には項目自体を含めない
        if can_view_stocks?
          by_site = usable_stock_by_site(data.map { |m| m["id"] })
          data = data.map { |m| m.merge("stock_by_site" => by_site[m["id"]] || []) }
        end

        render json: { data: data, meta: { total_count: total_count, page: page, per_page: per_page } }
      end

      # GET /api/v1/materials/:id
      def show
        authorize @material

        data = @material.as_json(include: { manufacturer: { only: [ :id, :name ] } }).merge(
          recent_orders: @material.orders.order(ordered_on: :desc).limit(5).as_json(
            include: { user: { only: [ :id, :name ] } }
          )
        )
        # 在庫は自社のみ（一覧の在庫と同じ。見られない人には項目自体を含めない）
        data.merge!(stock_summary_json) if can_view_stocks?

        render json: { data: data }
      end

      # POST /api/v1/materials
      def create
        material = Material.new(material_params)
        authorize material
        if material.save
          record_audit_log("create", material)
          render json: { data: material.as_json }, status: :created
        else
          render json: { errors: material.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/materials/:id
      def update
        authorize @material
        if @material.update(material_params)
          record_audit_log("update", @material)
          render json: { data: @material.as_json(include: { manufacturer: { only: [ :id, :name ] } }) }
        else
          render json: { errors: @material.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def can_view_stocks?
        policy(Stock).index?
      end

      # 使える在庫（利用可で数量が1以上）。使用中・修理中・廃棄済みは、探している人が使えないため含めない
      def usable_stocks
        Stock.available.where("stocks.quantity > 0")
      end

      # 資材ごとの拠点別の使える在庫数。自拠点を先頭に、そのあとは数量の多い順
      def usable_stock_by_site(material_ids)
        totals = usable_stocks.joins(:warehouse).where(material_id: material_ids)
                              .group(:material_id, "warehouses.site_id").sum(:quantity)
        names = Site.where(id: totals.keys.map(&:last)).pluck(:id, :name).to_h
        totals.group_by { |(material_id, _site_id), _qty| material_id }.transform_values do |entries|
          entries.map { |(_material_id, site_id), qty| { site_id: site_id, site_name: names[site_id], quantity: qty } }
                 .sort_by { |e| [ e[:site_id] == current_user.site_id ? 0 : 1, -e[:quantity], e[:site_id] ] }
        end
      end

      def filter_by_stock_availability(materials, mode)
        own = usable_stocks.joins(:warehouse).where(warehouses: { site_id: current_user.site_id }).select(:material_id)
        anywhere = usable_stocks.select(:material_id)
        case mode
        when "own" then materials.where(id: own)
        when "others_only" then materials.where(id: anywhere).where.not(id: own)
        when "none" then materials.where.not(id: anywhere)
        else materials
        end
      end

      # 詳細画面の在庫状況。倉庫ごと（拠点付き）の合計と使える数量。自拠点の倉庫を先頭にする
      def stock_summary_json
        totals = @material.stocks.group(:warehouse_id).sum(:quantity)
        usable = usable_stocks.where(material_id: @material.id).group(:warehouse_id).sum(:quantity)
        warehouses = Warehouse.includes(:site).where(id: totals.keys).index_by(&:id)
        rows = totals.map do |warehouse_id, qty|
          warehouse = warehouses[warehouse_id]
          { warehouse: warehouse&.name, site_id: warehouse&.site_id, site_name: warehouse&.site&.name,
            quantity: qty, usable_quantity: usable[warehouse_id] || 0 }
        end
        own = current_user.site_id
        { stock_summary: rows.sort_by { |r| [ r[:site_id] == own ? 0 : 1, -r[:usable_quantity], r[:warehouse].to_s ] },
          total_stock: totals.values.sum,
          usable_stock: usable.values.sum }
      end

      def set_material
        @material = Material.includes(:manufacturer, :stocks, orders: :user).find(params[:id])
      end

      def material_params
        params.require(:material).permit(
          :manufacturer_id, :part_number, :name, :description,
          :former_part_numbers, :availability, :category, :rating,
          :lead_time_days, :is_hazardous, :hazard_note,
          :reorder_method, :reorder_point, :reorder_quantity
        )
      end
    end
  end
end
