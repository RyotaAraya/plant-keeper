# フィクスチャは使わず、テストごとに必要なデータだけ作る（DBはテストごとにロールバックされる）
module TestData
  def create_company(company_type: "owner", name: "テスト石油")
    Company.create!(name: name, company_type: company_type)
  end

  def create_user(system_role: "member", company: create_company, is_active: true, **attrs)
    User.create!(
      name: "テストユーザ",
      email: "user-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      system_role: system_role,
      company: company,
      is_active: is_active,
      **attrs
    )
  end

  def create_site(name: "第一製油所")
    Site.create!(name: name)
  end

  def create_department(site: create_site, name: "保全部", level: "division", parent: nil)
    Department.create!(site: site, name: name, level: level, parent: parent, department_type: "maintenance")
  end

  def create_equipment(site: create_site, name: "原油蒸留装置")
    Equipment.create!(site: site, name: name)
  end

  def create_manufacturer(name: "テストメーカー")
    Manufacturer.create!(name: name)
  end

  def create_material(part_number:, name: "圧力伝送器", manufacturer: create_manufacturer)
    Material.create!(part_number: part_number, name: name, manufacturer: manufacturer)
  end
end
