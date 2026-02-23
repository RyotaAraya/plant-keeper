module Api
  module V1
    class SitesController < BaseController
      before_action :set_site, only: [ :show, :update ]

      # GET /api/v1/sites
      def index
        sites = Site.all
        sites = sites.where(is_active: params[:is_active]) if params[:is_active].present?

        sites = sites.order(:name)
        total_count = sites.count

        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        sites = sites.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: sites.as_json,
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      # GET /api/v1/sites/:id
      def show
        render json: {
          data: @site.as_json.merge(
            equipments_count: @site.equipments.count,
            warehouses_count: @site.warehouses.count
          )
        }
      end

      # POST /api/v1/sites
      def create
        site = Site.new(site_params)
        authorize site

        if site.save
          record_audit_log("create", site)
          render json: { data: site.as_json }, status: :created
        else
          render json: { errors: site.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/sites/:id
      def update
        authorize @site
        if @site.update(site_params)
          record_audit_log("update", @site)
          render json: { data: @site.as_json }
        else
          render json: { errors: @site.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_site
        @site = Site.find(params[:id])
      end

      def site_params
        params.require(:site).permit(:name, :prefecture, :address, :is_active, :closed_on)
      end
    end
  end
end
