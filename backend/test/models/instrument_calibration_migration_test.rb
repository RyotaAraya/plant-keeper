require "test_helper"
require Rails.root.join("db/migrate/20260920130100_seed_instrument_calibration")

# 既存の計器への校正条件（デモ用の既定値）・フラグの反映マイグレーション
class InstrumentCalibrationMigrationTest < ActiveSupport::TestCase
  setup do
    @site = Site.create!(name: "川崎製油所")
    @equipment = create_equipment(site: @site)
  end

  def create_instrument(tag, type, **attrs)
    Instrument.create!(equipment: @equipment, tag_number: tag, instrument_type: type, **attrs)
  end

  def run_migration
    ActiveRecord::Migration.suppress_messages { SeedInstrumentCalibration.new.up }
  end

  test "種別ごとの既定値を、校正範囲が未設定の計器にだけ入れる" do
    flow = create_instrument("FT-1", "flow_transmitter")
    valve = create_instrument("PV-1", "pressure_valve")
    hand = create_instrument("HV-1", "hand_valve")
    customized = create_instrument("PT-1", "pressure_transmitter", range_lower: 0, range_upper: 7, range_unit: "MPa", tolerance_percent: 0.1)

    2.times { run_migration }

    assert flow.reload.calibratable?
    assert_equal [ "square_root", 500 ], [ flow.dcs_characteristic, flow.dcs_range_upper ]
    assert_equal [ "transmitter", "positioner" ], [ flow.calibration_kind, valve.reload.calibration_kind ]
    assert valve.calibratable?
    assert_not hand.reload.calibratable?
    assert_equal [ 7, 0.1 ], [ customized.reload.range_upper, customized.tolerance_percent ] # 設定済みの計器には触れない
  end

  test "テレメータ・取引用の計器は、拠点とタグ番号が一致するものだけに印を付ける" do
    telemetry = create_instrument("FT-701", "flow_transmitter")
    other_site_equipment = create_equipment(site: create_site(name: "別製油所"), name: "別設備")
    other_site = Instrument.create!(equipment: other_site_equipment, tag_number: "FT-701", instrument_type: "flow_transmitter")
    custody = create_instrument("LT-1001", "level_transmitter")

    run_migration

    assert telemetry.reload.telemetry
    assert_not other_site.reload.telemetry
    assert custody.reload.custody_transfer
    assert_not custody.telemetry
  end
end
