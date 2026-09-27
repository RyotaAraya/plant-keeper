module Api
  module V1
    # ホーム（やること。HomeBoard）。GET /api/v1/home?site_id=1
    # 拠点は、拠点の一覧を見られる人（自社）だけが選べる。協力会社・指定なしは所属拠点
    class HomeController < BaseController
      include InterlockBypassJson

      def show
        authorize :home, :show?
        site = selected_site
        unless site
          render json: { errors: [ "拠点を指定してください" ] }, status: :unprocessable_entity
          return
        end

        board = HomeBoard.new(user: current_user, site: site)
        render json: { data: home_json(board) }
      end

      private

      def selected_site
        if params[:site_id].present? && SitePolicy.new(current_user, Site).index?
          Site.find_by(id: params[:site_id])
        else
          current_user.site
        end
      end

      def home_json(board)
        data = {
          today: board.today,
          tomorrow: board.tomorrow,
          kind: board.kind,
          site: board.site.as_json(only: [ :id, :name ]),
          interlock_bypasses: board.interlock_bypasses.map { |bypass| bypass_json(bypass) },
          diagnostic_troubles: board.unrouted_diagnostic_troubles.map { |trouble| trouble_json(trouble) },
          areas: board.area_departments.map { |department| area_json(board, department) }
        }
        if board.kind == "manager"
          data[:approvals] = {
            inspections: board.pending_inspections.map { |inspection| inspection_json(inspection) },
            interlock_bypasses: board.pending_bypasses.map { |bypass| bypass_json(bypass) }
          }
        end
        data[:my_troubles] = board.my_troubles.map { |trouble| trouble_json(trouble) } if board.kind == "operator"
        data
      end

      # department が nil のエリアは拠点全体
      def area_json(board, department)
        troubles = board.troubles(department)
        {
          department: department&.as_json(only: [ :id, :name, :level ]),
          inspection_plans: board.inspection_plans(department).map { |plan| plan_json(plan) },
          maintenance_tasks: board.maintenance_tasks(department).map { |task| task_json(task) },
          troubles: {
            total_count: troubles.count,
            items: troubles.includes(:equipment, :instrument, :assigned_to).limit(HomeBoard::TROUBLE_LIMIT).map { |trouble| trouble_json(trouble) }
          },
          # 夕会: 今日の実績（下書きのままの点検は、画面で積み残しとして分ける）
          results: {
            inspections: board.todays_inspections(department).map { |inspection| inspection_json(inspection) },
            trouble_responses: board.todays_responses(department).map { |response| response_json(response) },
            completed_tasks: board.completed_tasks(department).map { |task| completed_task_json(task) }
          }
        }
      end

      def plan_json(plan)
        plan.as_json(only: [ :id, :name, :next_due_on, :interval_days, :inspection_type, :equipment_id, :instrument_id,
                             :checklist_template_id, :reference_standard_id ],
                     methods: [ :days_until_due ],
                     include: { equipment: { only: [ :id, :name ] }, equipments: { only: [ :id, :name ] },
                                instrument: { only: [ :id, :tag_number ] }, reference_standard: { only: [ :id, :name ] },
                                inspection_plan_group: { only: [ :id, :name ] } })
      end

      def task_json(task)
        task.as_json(only: [ :id, :title, :kind, :status, :notes, :checklist_template_id ],
                     include: { scheduled_maintenance: { only: [ :id, :title ] }, equipment: { only: [ :id, :name ] },
                                instrument: { only: [ :id, :tag_number ] }, assigned_to: { only: [ :id, :name ] } })
      end

      def inspection_json(inspection)
        inspection.as_json(only: [ :id, :status, :inspection_type, :inspected_at, :equipment_id ],
                           include: { equipment: { only: [ :id, :name ] }, equipments: { only: [ :id, :name ] },
                                      instrument: { only: [ :id, :tag_number ] }, user: { only: [ :id, :name ] },
                                      department: { only: [ :id, :name ] }, checklist_template: { only: [ :id, :name ] } })
      end

      def response_json(response)
        response.as_json(only: [ :id, :response_type, :description, :responded_at ],
                         include: { user: { only: [ :id, :name ] },
                                    trouble: { only: [ :id, :title, :status ],
                                               include: { equipment: { only: [ :id, :name ] }, instrument: { only: [ :id, :tag_number ] } } } })
      end

      def completed_task_json(task)
        task.as_json(only: [ :id, :title, :kind, :completed_on ],
                     include: { scheduled_maintenance: { only: [ :id, :title ] }, department: { only: [ :id, :name ] },
                                equipment: { only: [ :id, :name ] }, instrument: { only: [ :id, :tag_number ] },
                                assigned_to: { only: [ :id, :name ] } })
      end

      def trouble_json(trouble)
        trouble.as_json(only: [ :id, :title, :status, :priority, :reported_at, :source ],
                        include: { equipment: { only: [ :id, :name ] }, instrument: { only: [ :id, :tag_number ] },
                                   assigned_to: { only: [ :id, :name ] } })
      end
    end
  end
end
