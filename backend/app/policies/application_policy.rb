# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show?   = false
  def create? = false
  def update? = false
  def destroy? = false
  def new?    = create?
  def edit?   = update?

  class Scope
    def initialize(user, scope)
      @user  = user
      @scope = scope
    end

    def resolve = scope.all

    private

    attr_reader :user, :scope
  end

  private

  def admin?
    user.admin?
  end

  def owner_manager?
    user.manager? && user.company&.company_type == "owner"
  end

  def contractor_manager?
    user.manager? && user.company&.company_type == "contractor"
  end

  def owner_company?
    user.company&.company_type == "owner"
  end
end
