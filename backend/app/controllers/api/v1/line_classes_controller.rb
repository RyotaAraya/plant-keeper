module Api
  module V1
    class LineClassesController < BaseController
      def index
        render json: { data: LineClass.order(:code).as_json }
      end

      def create
        line_class = LineClass.new(line_class_params)
        authorize line_class
        if line_class.save
          render json: { data: line_class.as_json }, status: :created
        else
          render json: { errors: line_class.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        line_class = LineClass.find(params[:id])
        authorize line_class
        if line_class.update(line_class_params)
          render json: { data: line_class.as_json }
        else
          render json: { errors: line_class.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def line_class_params
        params.require(:line_class).permit(:code, :description)
      end
    end
  end
end
