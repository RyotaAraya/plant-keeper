require "test_helper"

# タグ番号は拠点内で一意（別拠点なら同じ番号があり得る）
class InstrumentTest < ActiveSupport::TestCase
  test "別の拠点なら同じタグ番号を登録できる" do
    a = create_equipment(site: create_site(name: "A製油所"))
    b = create_equipment(site: create_site(name: "B製油所"))
    Instrument.create!(equipment: a, tag_number: "PI-101")

    assert Instrument.new(equipment: b, tag_number: "PI-101").valid?
  end

  test "同じ拠点内ではタグ番号が重複できない（別設備でも）" do
    site = create_site
    a = create_equipment(site: site, name: "設備A")
    b = create_equipment(site: site, name: "設備B")
    Instrument.create!(equipment: a, tag_number: "PI-101")

    dup = Instrument.new(equipment: b, tag_number: "PI-101")
    assert_not dup.valid?
    assert dup.errors[:tag_number].any?
  end

  test "自分自身を更新してもタグ番号の重複にならない" do
    inst = Instrument.create!(equipment: create_equipment, tag_number: "PI-101", notes: "旧")
    assert inst.update(notes: "新")
  end

  test "DBでも同一設備内のタグ番号重複は保存できない" do
    equipment = create_equipment
    Instrument.create!(equipment: equipment, tag_number: "PI-101")

    assert_raises(ActiveRecord::RecordNotUnique) do
      Instrument.new(equipment: equipment, tag_number: "PI-101").save!(validate: false)
    end
  end
end
