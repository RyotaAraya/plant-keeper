module Api
  module V1
    class DashboardController < BaseController
      # GET /api/v1/dashboard?site_id=1
      def show
        authorize :dashboard, :show?
        dashboard_policy = policy(:dashboard)
        site_id = params[:site_id].presence

        troubles_scope = Trouble.joins(:equipment)
        troubles_scope = troubles_scope.where(equipments: { site_id: site_id }) if site_id

        inspections_scope = Inspection.joins(:equipment)
        inspections_scope = inspections_scope.where(equipments: { site_id: site_id }) if site_id

        maintenances_scope = ScheduledMaintenance.joins(:equipment)
        maintenances_scope = maintenances_scope.where(equipments: { site_id: site_id }) if site_id

        plans_scope = InspectionPlan.active.joins(:equipment)
        plans_scope = plans_scope.where(equipments: { site_id: site_id }) if site_id

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

        data = {
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
            # 点検計画（期限超過・期限間近）
            inspection_plans: {
              overdue: plans_scope.merge(InspectionPlan.overdue).count,
              due_soon: plans_scope.merge(InspectionPlan.due_within(7)).count,
              overdue_list: plans_scope.merge(InspectionPlan.overdue).includes(:instrument).order(:next_due_on).limit(5)
                .as_json(methods: [ :days_until_due ], include: { equipment: { only: [ :id, :name ] }, instrument: { only: [ :id, :tag_number ] } })
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
            }
          }

        # 資材・発注・修理は、それぞれの一覧画面を見られる人にだけ返す（権限のない人には項目自体を含めない）
        if dashboard_policy.stocks?
          # 在庫アラート（発注点以下の資材）
          data[:stock_alerts] = materials_scope
            .select { |m| stock_total.call(m) <= m.reorder_point }
            .first(10)
            .map { |m| { id: m.id, name: m.name, part_number: m.part_number, total_stock: stock_total.call(m), reorder_point: m.reorder_point } }
        end
        if dashboard_policy.orders?
          # 発注状況（資材・発注は拠点横断の共通マスタのため、拠点で絞り込まない）
          data[:orders] = {
            draft: Order.draft.count,
            ordered: Order.ordered.count,
            recent: Order.order(ordered_on: :desc).limit(5).as_json(
              include: { material: { only: [ :id, :name ] }, user: { only: [ :id, :name ] } }
            )
          }
        end
        if dashboard_policy.repairs?
          data[:repairs] = {
            pending: repairs_scope.pending.count,
            in_repair: repairs_scope.in_repair.count
          }
        end

        render json: { data: data }
      end
    end
  end
end
