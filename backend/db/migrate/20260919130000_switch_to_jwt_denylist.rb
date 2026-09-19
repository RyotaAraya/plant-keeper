class SwitchToJwtDenylist < ActiveRecord::Migration[8.0]
  def change
    # トークンの失効を「ユーザ単位のjti（JTIMatcher）」から「トークン単位の失効リスト（Denylist）」に切り替える。
    # 1ユーザ1jtiだと、どこか1端末でログアウトした時点で全端末が切れてしまうため
    create_table :jwt_denylists do |t|
      t.string :jti, null: false
      t.datetime :exp, null: false
    end
    add_index :jwt_denylists, :jti, unique: true
    add_index :jwt_denylists, :exp

    # users.jti はもう使わない。切り替え中に旧バージョンのプロセスが動いていても壊れないよう、
    # カラムは残して NULL を許可するだけにする（削除は次のリリースで行う）
    change_column_null :users, :jti, true
  end
end
