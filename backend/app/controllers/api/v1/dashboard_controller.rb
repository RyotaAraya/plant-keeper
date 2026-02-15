module Api
  module V1
    class DashboardController < BaseController
      # GET /api/v1/dashboard
      def show
        render json: {
          data: {
            # トラブル統計
            troubles: {
              open: Trouble.open.count,
              in_progress: Trouble.in_progress.count,
              critical: Trouble.where(priority: "critical").where.not(status: "closed").count,
              resolved_this_month: Trouble.resolved.where("resolved_at >= ?", Time.current.beginning_of_month).count
            },
            # 点検統計
            inspections: {
              pending_approval: Inspection.approval_requested.count,
              this_month: Inspection.where("inspected_at >= ?", Time.current.beginning_of_month).count,
              draft: Inspection.draft.count
            },
            # 定期整備
            maintenances: {
              planned: ScheduledMaintenance.planned.count,
              in_progress: ScheduledMaintenance.in_progress.count,
              upcoming: ScheduledMaintenance.planned
                .where(scheduled_date: Date.today..30.days.from_now)
                .order(:scheduled_date)
                .limit(5)
                .as_json(include: { equipment: { only: [ :id, :name ] } })
            },
            # 在庫アラート（発注点以下の資材）
            stock_alerts: Material
              .where(reorder_method: "reorder_point")
              .where.not(reorder_point: nil)
              .select { |m|
                total = m.stocks.sum(:quantity)
                total <= m.reorder_point
              }
              .first(10)
              .map { |m| { id: m.id, name: m.name, part_number: m.part_number, total_stock: m.stocks.sum(:quantity), reorder_point: m.reorder_point } },
            # 発注状況
            orders: {
              draft: Order.draft.count,
              ordered: Order.ordered.count,
              recent: Order.order(ordered_on: :desc).limit(5).as_json(
                include: { material: { only: [ :id, :name ] }, user: { only: [ :id, :name ] } }
              )
            },
            # 修理状況
            repairs: {
              pending: Repair.pending.count,
              in_repair: Repair.in_repair.count
            }
          }
        }
      end
    end
  end
end
