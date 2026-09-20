require "test_helper"
require Rails.root.join("db/migrate/20260921040000_rename_instrumentation_section")

# 部署名「計器保全課」→「計装保全課」の、既存環境への反映マイグレーション
class RenameInstrumentationSectionMigrationTest < ActiveSupport::TestCase
  def run_migration
    ActiveRecord::Migration.suppress_messages { RenameInstrumentationSection.new.up }
  end

  test "旧名の部署と、基準器の保管場所・校正者の文言を直し、ほかの部署や文言には触れない。何度実行しても同じ" do
    site = create_site
    division = create_department(site: site, name: "保全部", level: "division")
    old_section = create_department(site: site, name: "計器保全課", level: "section", parent: division)
    other_section = create_department(site: site, name: "電気保全課", level: "section", parent: division)
    standard = ReferenceStandard.create!(site: site, management_number: "RS-T-001", name: "デジタル圧力計", location: "計器保全課 校正室")
    other = ReferenceStandard.create!(site: site, management_number: "RS-T-002", name: "テスター", location: "電気保全課 工具室")
    calibration = standard.calibrations.create!(performed_on: Date.current, performed_by: "社内（計器保全課）", result: "pass", valid_until: Date.current + 365)

    2.times { run_migration }

    assert_equal "計装保全課", old_section.reload.name
    assert_equal "電気保全課", other_section.reload.name
    assert_equal [ "計装保全課 校正室", "電気保全課 工具室" ], [ standard.reload.location, other.reload.location ]
    assert_equal "社内（計装保全課）", calibration.reload.performed_by
  end
end
