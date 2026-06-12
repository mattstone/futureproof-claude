# Reference implementation of the ResourceController DSL (index + CSV).
# Show page, security panel and account actions land in Phase 1c.
class Console::UsersController < Console::ResourceController
  before_action -> { require_capability(:manage_users) }

  resource User
  searches "users.email", "users.first_name", "users.last_name"
  sortable email: "users.email",
           name: "users.last_name",
           created: "users.created_at"
  default_sort :created, :desc
  filters role: ->(scope, value) { value == "admin" ? scope.where(admin: true) : scope.where(admin: false) },
          country: ->(scope, value) { scope.where(country_of_residence: value) }
  preloads :lender

  csv_column("Email") { |user| user.email }
  csv_column("Name") { |user| user.full_name }
  csv_column("Role") { |user| user.admin? ? "Admin" : "Customer" }
  csv_column("Lender") { |user| user.lender&.name }
  csv_column("Country") { |user| user.country_of_residence }
  csv_column("Joined") { |user| user.created_at.to_date.iso8601 }

  protected

  # Futureproof admins see everyone; lender admins see their own book.
  def base_scope
    if policy.futureproof?
      User.all
    else
      User.where(lender: policy.lender)
    end
  end
end
