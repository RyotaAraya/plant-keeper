class UserSerializer
  def initialize(user)
    @user = user
  end

  def as_json
    {
      id: @user.id,
      email: @user.email,
      name: @user.name,
      role: @user.role,
      department_id: @user.department_id,
      is_active: @user.is_active,
      join_year: @user.join_year
    }
  end
end
