module Api
  module V1
    # 朝会・夕会ボード（MeetingBoard）。GET /api/v1/meeting_board?site_ids[]=1&department_id=2
    class MeetingBoardsController < BaseController
      include InterlockBypassJson

      def show
        authorize :meeting_board, :show?
        site_ids = id_list_param(:site_ids, :site_id)
        department = department_in(site_ids)
        if params[:department_id].present? && department.nil?
          render json: { errors: [ "選択した拠点の部署を指定してください" ] }, status: :unprocessable_entity
          return
        end

        board = MeetingBoard.new(site_ids: site_ids, department: department)
        troubles = board.troubles
        render json: { data: {
          today: board.today,
          tomorrow: board.tomorrow,
          scope: {
            site_name: site_ids&.one? ? Site.find_by(id: site_ids.first)&.name : nil,
            department_name: department&.name
          },
          inspection_plans: board.inspection_plans.map { |plan| plan_json(plan) },
          maintenances: board.maintenances.map { |entry| maintenance_json(entry[:maintenance], entry[:tasks]) },
          troubles: {
            total_count: troubles.count,
            items: troubles.includes(:equipment, :instrument, :assigned_to).limit(MeetingBoard::TROUBLE_LIMIT).map { |trouble| trouble_json(trouble) }
          },
          interlock_bypasses: board.interlock_bypasses.map { |bypass| bypass_json(bypass) }
        } }
      end

      private

      # ダッシュボードと同じく、部署は選んだ拠点のものだけ（存在しない・別拠点の部署は拒否し、全件に戻さない）
      def department_in(site_ids)
        return if params[:department_id].blank?

        scope = Department.where(id: params[:department_id])
        scope = scope.where(site_id: site_ids) if site_ids
        scope.first
      end

      def plan_json(plan)
        plan.as_json(only: [ :id, :name, :next_due_on, :interval_days, :inspection_type, :equipment_id, :instrument_id,
                             :checklist_template_id, :reference_standard_id ],
                     methods: [ :days_until_due ],
                     include: { equipment: { only: [ :id, :name ] }, equipments: { only: [ :id, :name ] },
                                instrument: { only: [ :id, :tag_number ] }, reference_standard: { only: [ :id, :name ] },
                                checklist_template: { only: [ :id, :name ], include: { department: { only: [ :id, :name ] } } } })
      end

      # 進み具合は、範囲の作業（見送りを除く）のうち完了した数
      def maintenance_json(maintenance, tasks)
        counted = tasks.reject(&:cancelled?)
        maintenance.as_json(only: [ :id, :title, :status, :planned_start_on, :planned_end_on, :actual_start_on ],
                            include: { site: { only: [ :id, :name ] } }).merge(
          "task_count" => counted.size,
          "completed_count" => counted.count(&:completed?),
          "open_tasks" => tasks.select { |task| MeetingBoard::OPEN_TASK_STATUSES.include?(task.status) }.map do |task|
            task.as_json(only: [ :id, :title, :kind, :status, :notes, :checklist_template_id ],
                         include: { department: { only: [ :id, :name ] }, equipment: { only: [ :id, :name ] },
                                    instrument: { only: [ :id, :tag_number ] }, assigned_to: { only: [ :id, :name ] } })
          end
        )
      end

      def trouble_json(trouble)
        trouble.as_json(only: [ :id, :title, :status, :priority, :reported_at ],
                        include: { equipment: { only: [ :id, :name ] }, instrument: { only: [ :id, :tag_number ] },
                                   assigned_to: { only: [ :id, :name ] } })
      end
    end
  end
end
