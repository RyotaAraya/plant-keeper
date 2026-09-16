module Api
  module V1
    class DashboardController < BaseController
      # GET /api/v1/dashboard?site_id=1
      def show
        site_id = params[:site_id].presence

        troubles_scope = Trouble.joins(:equipment)
        troubles_scope = troubles_scope.where(equipments: { site_id: site_id }) if site_id

        inspections_scope = Inspection.joins(:equipment)
        inspections_scope = inspections_scope.where(equipments: { site_id: site_id }) if site_id

        maintenances_scope = ScheduledMaintenance.joins(:equipment)
        maintenances_scope = maintenances_scope.where(equipments: { site_id: site_id }) if site_id

        repairs_scope = Repair.joins(stock: :warehouse)
        repairs_scope = repairs_scope.where(warehouses: { site_id: site_id }) if site_id

        # 在庫アラート対象の資材。site_id指定時はその拠点に在庫を持つ資材に絞り、
        # 在庫数もその拠点分のみで判定する（reorder_pointは資材マスタ側の拠点横断の閾値）
        materials_scope = Material.where(reorder_method: "reorder_point").where.not(reorder_point: nil)
        materials_scope = materials_scope.joins(stocks: :warehouse).where(warehouses: { site_id: site_id }).distinct if site_id
        stock_total = ->(material) {
          if site_id
            material.stocks.joins(:warehouse).where(warehouses: { site_id: site_id }).sum(:quantity)
          else
            material.stocks.sum(:quantity)
          end
        }

        render json: {
          data: {
            # トラブル統計
            troubles: {
              open: troubles_scope.open.count,
              in_progress: troubles_scope.in_progress.count,
              critical: troubles_scope.where(priority: "critical").where.not(status: "closed").count,
              resolved_this_month: troubles_scope.resolved.where("resolved_at >= ?", Time.current.beginning_of_month).count
            },
            # 点検統計
            inspections: {
              pending_approval: inspections_scope.approval_requested.count,
              this_month: inspections_scope.where("inspected_at >= ?", Time.current.beginning_of_month).count,
              draft: inspections_scope.draft.count
            },
            # 定期整備
            maintenances: {
              planned: maintenances_scope.planned.count,
              in_progress: maintenances_scope.in_progress.count,
              upcoming: maintenances_scope.planned
                .where(scheduled_date: Date.today..30.days.from_now)
                .order(:scheduled_date)
                .limit(5)
                .as_json(include: { equipment: { only: [ :id, :name ] } })
            },
            # 在庫アラート（発注点以下の資材）
            stock_alerts: materials_scope
              .select { |m| stock_total.call(m) <= m.reorder_point }
              .first(10)
              .map { |m| { id: m.id, name: m.name, part_number: m.part_number, total_stock: stock_total.call(m), reorder_point: m.reorder_point } },
            # 発注状況（資材・発注は拠点横断の共通マスタのため、拠点で絞り込まない）
            orders: {
              draft: Order.draft.count,
              ordered: Order.ordered.count,
              recent: Order.order(ordered_on: :desc).limit(5).as_json(
                include: { material: { only: [ :id, :name ] }, user: { only: [ :id, :name ] } }
              )
            },
            # 修理状況
            repairs: {
              pending: repairs_scope.pending.count,
              in_repair: repairs_scope.in_repair.count
            }
          }
        }
      end
    end
  end
end
