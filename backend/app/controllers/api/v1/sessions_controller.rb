module Api
  module V1
    class SessionsController < Devise::SessionsController
      respond_to :json

      # ログイン成功を監査ログに残す（失敗は Devise が401を返し、ここには来ない）
      def create
        super do |resource|
          AuditLog.create!(
            user: resource, action: "login", auditable: resource,
            ip_address: request.remote_ip, performed_at: Time.current
          )
        end
      end

      private

      def respond_with(resource, _opts = {})
        token = request.env["warden-jwt_auth.token"]
        render json: {
          user: UserSerializer.new(resource).as_json,
          token: token
        }, status: :ok
      end

      def respond_to_on_destroy(**)
        head :no_content
      end
    end
  end
end
