ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

# DATABASE_URL が開発DBを指したままだと、rails/test_help の maintain_test_schema でDBが初期化されうる。
# 接続先が *_test 以外なら、test_help を読み込む前に中断する。
db_name = ActiveRecord::Base.connection_db_config.database.to_s
unless db_name.end_with?("_test")
  abort "テストは *_test のDBでのみ実行できます（現在の接続先: #{db_name}）。" \
        "docker-compose の場合は README/CLAUDE.md の「テスト」の手順で DATABASE_URL を指定してください。"
end

require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |f| require f }

class ActiveSupport::TestCase
  include TestData
end

class ActionDispatch::IntegrationTest
  include ApiHelper
end
