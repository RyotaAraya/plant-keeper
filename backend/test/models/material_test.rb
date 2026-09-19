require "test_helper"

class MaterialTest < ActiveSupport::TestCase
  test "保存時にハイフンとスペースを除いた正規化型番が設定される" do
    material = create_material(part_number: "AB-12 3-C")

    assert_equal "AB123C", material.normalized_part_number
  end

  test "型番を変更すると正規化型番も更新される" do
    material = create_material(part_number: "AB-123")

    material.update!(part_number: "CD-456")

    assert_equal "CD456", material.normalized_part_number
  end

  test "型番と名称は必須" do
    material = Material.new(manufacturer: create_manufacturer)

    assert_not material.valid?
    assert material.errors.of_kind?(:part_number, :blank)
    assert material.errors.of_kind?(:name, :blank)
  end
end
