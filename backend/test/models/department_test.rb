require "test_helper"

# 部署は拠点ごとに 部(division) → 課(section) → チーム(team) の3階層
class DepartmentTest < ActiveSupport::TestCase
  setup do
    @site = create_site
    @division = create_department(site: @site, name: "保全部", level: "division")
    @section = create_department(site: @site, name: "計器保全課", level: "section", parent: @division)
  end

  test "部・課・チームの階層を作れ、full_pathで辿れる" do
    team = create_department(site: @site, name: "計器Aチーム", level: "team", parent: @section)

    assert_equal "保全部 > 計器保全課 > 計器Aチーム", team.full_path
    assert_equal %w[division section team], team.ancestor_chain.map { |d| d[:level] }
  end

  test "部には親部署を設定できない" do
    department = Department.new(site: @site, name: "別の部", level: "division", parent: @division, department_type: "maintenance")

    assert_not department.valid?
    assert department.errors.key?(:parent)
  end

  test "課の親は部でなければならない" do
    department = Department.new(site: @site, name: "別の課", level: "section", parent: @section, department_type: "maintenance")

    assert_not department.valid?
    assert department.errors.key?(:parent)
  end

  test "チームの親は課でなければならない" do
    department = Department.new(site: @site, name: "チーム", level: "team", parent: @division, department_type: "maintenance")

    assert_not department.valid?
    assert department.errors.key?(:parent)
  end

  test "親部署は同じ拠点でなければならない" do
    other_site_division = create_department(site: create_site(name: "第二製油所"), level: "division")
    department = Department.new(site: @site, name: "課", level: "section", parent: other_site_division, department_type: "maintenance")

    assert_not department.valid?
    assert department.errors.key?(:parent)
  end

  test "自身を親部署に設定できない" do
    @division.parent = @division

    assert_not @division.valid?
    assert @division.errors.key?(:parent)
  end
end
