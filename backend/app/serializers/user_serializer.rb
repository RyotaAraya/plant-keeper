class UserSerializer
  def initialize(user)
    @user = user
  end

  def as_json
    {
      id: @user.id,
      email: @user.email,
      name: @user.name,
      employment_type: @user.employment_type,
      system_role: @user.system_role,
      company_id: @user.company_id,
      company: company_json,
      department_id: @user.department_id,
      site_id: @user.site_id,
      site: site_json,
      is_active: @user.is_active,
      join_year: @user.join_year
    }
  end

  private

  # ヘッダーに所属拠点を表示するため（拠点の一覧を見られない協力会社にも、自分の拠点だけは返す）
  def site_json
    site = @user.site
    return if site.nil?

    { id: site.id, name: site.name }
  end

  # フロントの権限判定（自社/協力会社）とヘッダー表示が user.company を参照する
  def company_json
    company = @user.company
    return if company.nil?

    { id: company.id, name: company.name, company_type: company.company_type }
  end
end
