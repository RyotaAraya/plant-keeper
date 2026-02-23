module Api
  module V1
    class CompaniesController < BaseController
      def index
        companies = Company.all
        companies = companies.where(company_type: params[:company_type]) if params[:company_type].present?
        companies = companies.where(is_active: true) unless params[:include_inactive] == "true"

        render json: {
          data: companies.order(:company_type, :name).as_json(only: [ :id, :name, :company_type, :is_active ])
        }
      end

      def create
        company = Company.new(company_params)
        authorize company
        if company.save
          render json: { data: company.as_json(only: [ :id, :name, :company_type, :is_active ]) }, status: :created
        else
          render json: { errors: company.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        company = Company.find(params[:id])
        authorize company
        if company.update(company_params)
          render json: { data: company.as_json(only: [ :id, :name, :company_type, :is_active ]) }
        else
          render json: { errors: company.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def company_params
        params.require(:company).permit(:name, :company_type, :is_active)
      end
    end
  end
end
