module Api
  module V1
    class DepartmentsController < BaseController
      def show
        dept = Department.includes(:site, :parent, :children,
                                   department_histories: :user).find(params[:id])
        current_members = dept.department_histories.current.map do |dh|
          {
            id: dh.id,
            user: dh.user.as_json(only: [ :id, :name, :email ]),
            role_note: dh.role_note,
            started_on: dh.started_on
          }
        end
        render json: {
          data: dept.as_json(include: {
            site: { only: [ :id, :name ] },
            parent: { only: [ :id, :name, :level ] },
            children: { only: [ :id, :name, :level ] }
          }).merge(current_members: current_members)
        }
      end

      def index
        departments = Department.includes(:site, :parent)
        departments = departments.where(site_id: params[:site_id]) if params[:site_id].present?
        departments = departments.where(department_type: params[:department_type]) if params[:department_type].present?
        departments = departments.where(level: params[:level]) if params[:level].present?
        departments = departments.where(parent_id: params[:parent_id]) if params[:parent_id].present?

        if params[:tree] == "true"
          render json: { data: build_tree(departments) }
        else
          render json: {
            data: departments.order(:level, :name).map { |d|
              d.as_json(
                include: {
                  site: { only: [ :id, :name ] },
                  parent: { only: [ :id, :name, :level ] }
                }
              ).merge(full_path: d.full_path)
            }
          }
        end
      end

      def create
        department = Department.new(department_params)
        authorize department
        if department.save
          render json: { data: department.as_json(include: { site: { only: [ :id, :name ] }, parent: { only: [ :id, :name, :level ] } }) }, status: :created
        else
          render json: { errors: department.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        department = Department.find(params[:id])
        authorize department
        if department.update(update_params)
          render json: { data: department.as_json(include: { site: { only: [ :id, :name ] }, parent: { only: [ :id, :name, :level ] } }) }
        else
          render json: { errors: department.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def department_params
        params.require(:department).permit(:name, :department_type, :site_id, :parent_id, :level)
      end

      def update_params
        params.require(:department).permit(:name, :department_type, :parent_id, :level)
      end

      def build_tree(departments)
        all = departments.order(:level, :name).to_a
        roots = all.select { |d| d.parent_id.nil? }
        roots.map { |r| department_node(r, all) }
      end

      def department_node(dept, all)
        children = all.select { |d| d.parent_id == dept.id }
        {
          id: dept.id,
          name: dept.name,
          level: dept.level,
          department_type: dept.department_type,
          site_id: dept.site_id,
          children: children.map { |c| department_node(c, all) }
        }
      end
    end
  end
end
