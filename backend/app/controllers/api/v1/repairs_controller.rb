module Api
  module V1
    class RepairsController < BaseController
      before_action :set_repair, only: [ :show, :update ]

      # GET /api/v1/repairs
      def index
        authorize Repair
        repairs = Repair.includes(:stock, :requested_by, stock: :material).all
        if (site_ids = id_list_param(:site_ids, :site_id))
          repairs = repairs.where(stock_id: Stock.where(warehouse_id: Warehouse.where(site_id: site_ids).select(:id)).select(:id))
        end
        if (statuses = value_list_param(:statuses, :status))
          repairs = repairs.where(status: statuses)
        end

        repairs = repairs.order(created_at: :desc)
        total_count = repairs.count

        page, per_page = pagination_params
        repairs = repairs.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: repairs.as_json(
            include: {
              stock: { include: { material: { only: [ :id, :name, :part_number ] } }, only: [ :id, :serial_number ] },
              requested_by: { only: [ :id, :name ] }
            }
          ),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/repairs/:id
      def show
        authorize @repair
        render json: {
          data: @repair.as_json(
            include: {
              stock: {
                include: {
                  material: { only: [ :id, :name, :part_number ] },
                  warehouse: { only: [ :id, :name ] }
                }
              },
              trouble: { only: [ :id, :title, :status ] },
              requested_by: { only: [ :id, :name ] }
            }
          )
        }
      end

      # POST /api/v1/repairs
      def create
        repair = Repair.new(create_params)
        authorize repair
        repair.requested_by = current_user

        # 修理は依頼中から始まる（完了・廃棄で作成すると、在庫の状態と食い違う）
        unless repair.pending?
          return render json: { errors: [ "新規登録できるのは依頼中のみです" ] }, status: :unprocessable_entity
        end

        ActiveRecord::Base.transaction do
          source = Stock.lock.find_by(id: repair.stock_id)
          if source && !repairable?(source)
            repair.errors.add(:stock, "は修理を依頼できる状態ではありません（在庫あり・使用中のみ）")
            raise ActiveRecord::RecordInvalid, repair
          end

          # 修理に出すのは1個。数量2以上のロットからは1個を切り出して修理の対象にする
          # （ロット全体が「修理中」になり、残りの良品まで使えなくなるのを防ぐ）
          repair.stock = detach_one_unit(source) if source
          repair.save!
          record_audit_log("create", repair)
        end

        render json: { data: repair.as_json }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # PATCH /api/v1/repairs/:id
      def update
        authorize @repair

        # 修理の状態と、修理対象の在庫の状態は一緒に更新する（片方だけ変わって食い違わないように）
        ActiveRecord::Base.transaction do
          @repair.lock!
          @repair.update!(update_params)
          record_audit_log("update", @repair)
          case @repair.status
          when "shipped" then @repair.stock.update!(status: "under_repair")
          when "completed" then @repair.stock.update!(status: "available")
          when "disposed" then @repair.stock.update!(status: "disposed")
          end
        end

        render json: { data: @repair.as_json }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def repairable?(stock)
        stock.quantity >= 1 && (stock.available? || stock.in_use?)
      end

      # 数量1ならその在庫自体を修理待ちにし、2以上なら1個を別行に切り出す。修理対象の在庫を返す
      def detach_one_unit(source)
        if source.quantity == 1
          source.update!(status: "awaiting_repair")
          source
        else
          source.update!(quantity: source.quantity - 1)
          Stock.create!(
            material_id: source.material_id, warehouse_id: source.warehouse_id, quantity: 1,
            purchased_on: source.purchased_on, status: "awaiting_repair", notes: source.notes
          )
        end
      end

      def set_repair
        @repair = Repair.includes(:stock, :trouble, :requested_by, stock: [ :material, :warehouse ]).find(params[:id])
      end

      def create_params
        params.require(:repair).permit(
          :stock_id, :trouble_id, :status, :repair_vendor,
          :shipped_on, :completed_on, :received_on,
          :repair_cost, :shipping_cost, :disposition, :notes
        )
      end

      # 修理対象の在庫（stock_id）は変えられない（別の在庫の状態を書き換えてしまうため）
      def update_params
        create_params.except(:stock_id)
      end
    end
  end
end
