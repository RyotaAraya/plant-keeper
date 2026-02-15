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
      department_id: @user.department_id,
      is_active: @user.is_active,
      join_year: @user.join_year
    }
  end
end
