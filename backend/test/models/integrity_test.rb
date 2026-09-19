require "test_helper"

# 計器は、対象の設備に属するものでなければならない
class IntegrityTest < ActiveSupport::TestCase
  setup do
    @site = create_site
    @equipment = create_equipment(site: @site, name: "設備A")
    @other_equipment = create_equipment(site: @site, name: "設備B")
    @instrument = Instrument.create!(equipment: @equipment, tag_number: "PI-101")
    @other_instrument = Instrument.create!(equipment: @other_equipment, tag_number: "PI-201")
    @user = create_user
    @department = create_department(site: @site)
  end

  def inspection(attrs = {})
    Inspection.new({ user: @user, equipment: @equipment, department: @department,
                     inspection_type: "routine", inspected_at: Time.current }.merge(attrs))
  end

  test "点検の計器は、点検の設備に属していなければならない" do
    assert inspection(instrument: @instrument).valid?

    bad = inspection(instrument: @other_instrument)
    assert_not bad.valid?
    assert bad.errors[:instrument].any?
  end

  test "点検項目の計器は、点検の設備に属していなければならない" do
    saved = inspection.tap(&:save!)

    assert InspectionItem.new(inspection: saved, position: 1, content: "確認", instrument: @instrument).valid?
    assert_not InspectionItem.new(inspection: saved, position: 1, content: "確認", instrument: @other_instrument).valid?
  end

  test "トラブルの計器は、トラブルの設備に属していなければならない" do
    attrs = { equipment: @equipment, reported_by: @user, title: "指示値異常", reported_at: Time.current }

    assert Trouble.new(attrs.merge(instrument: @instrument)).valid?
    bad = Trouble.new(attrs.merge(instrument: @other_instrument))
    assert_not bad.valid?
    assert bad.errors[:instrument].any?
  end

  test "計器を指定しない（設備全体の）点検・トラブルは有効" do
    assert inspection.valid?
    assert Trouble.new(equipment: @equipment, reported_by: @user, title: "設備全体", reported_at: Time.current).valid?
  end
end
