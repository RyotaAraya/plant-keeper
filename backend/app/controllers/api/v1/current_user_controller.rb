module Api
  module V1
    class CurrentUserController < BaseController
      # 自分自身の情報を返すだけで、認可の対象となるリソースがない
      skip_after_action :verify_authorized

      def show
        render json: { user: UserSerializer.new(current_user).as_json }
      end
    end
  end
end
