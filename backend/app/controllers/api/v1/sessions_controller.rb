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

      # ログアウトを監査ログに残す。トークンの失効は devise-jwt のミドルウェアがこのあとで行う。
      # JWT にはセッションがないため、Devise の verify_signed_out_user は常に「ログアウト済み」と判定して
      # destroy を呼ばずに終わる。それを外し、トークンで認証できたときだけ記録する（トークンなしは記録せず204）
      skip_before_action :verify_signed_out_user, only: :destroy

      def destroy
        user = current_user
        if user
          AuditLog.create!(
            user: user, action: "logout", auditable: user,
            ip_address: request.remote_ip, performed_at: Time.current
          )
        end
        respond_to_on_destroy
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
