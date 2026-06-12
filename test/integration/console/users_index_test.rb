require "test_helper"

# Exercises the ResourceController DSL end-to-end through its reference
# implementation (console/users): search, filters, sort whitelist, CSV,
# pagination, and lender scoping.
class Console::UsersIndexTest < ActionDispatch::IntegrationTest
  test "index renders through the component kit" do
    sign_in users(:admin_user)
    get console_users_path

    assert_response :success
    assert_select "turbo-frame#users table.console-table"
    assert_select ".console-filter-bar"
    assert_select "a.console-table-csv"
  end

  test "search narrows by email and name" do
    sign_in users(:admin_user)
    get console_users_path(search: users(:jane).email)

    assert_response :success
    assert_select "td", text: users(:jane).email
    assert_select "td", { text: users(:regular_user).email, count: 0 }
  end

  test "role filter splits admins from customers" do
    sign_in users(:admin_user)
    get console_users_path(role: "admin")

    assert_response :success
    assert_select "td", text: users(:admin_user).email
    assert_select "td", { text: users(:regular_user).email, count: 0 }
  end

  test "unknown sort keys fall back to the default instead of reaching SQL" do
    sign_in users(:admin_user)
    get console_users_path(sort: "users.encrypted_password; DROP TABLE users;", direction: "asc")

    assert_response :success
  end

  test "sorting by a whitelisted key works both directions" do
    sign_in users(:admin_user)
    get console_users_path(sort: "email", direction: "asc")
    assert_response :success
    first_asc = css_select("tbody td").first.text.strip

    get console_users_path(sort: "email", direction: "desc")
    assert_response :success
    first_desc = css_select("tbody td").first.text.strip

    assert_not_equal first_asc, first_desc
  end

  test "csv export honours the same filters" do
    sign_in users(:admin_user)
    get console_users_path(format: :csv, role: "admin")

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, users(:admin_user).email
    assert_not_includes response.body, users(:regular_user).email
  end

  test "collections paginate at 25 per page" do
    base = users(:regular_user)
    rows = 30.times.map do |i|
      {
        email: "pagination-#{i}@example.com",
        first_name: "Page", last_name: "Tester#{i}",
        encrypted_password: base.encrypted_password,
        country_of_residence: "Australia",
        lender_id: base.lender_id,
        confirmed_at: Time.current, created_at: Time.current, updated_at: Time.current
      }
    end
    User.insert_all(rows)

    sign_in users(:admin_user)
    get console_users_path

    assert_response :success
    assert_select "tbody tr", count: 25
    assert_select "nav.console-pagination"

    get console_users_path(page: 2)
    assert_response :success
    assert_select "tbody tr", { minimum: 1 }
  end

  test "lender admins only see their own lender's users" do
    sign_in users(:lender_admin_user)
    get console_users_path

    assert_response :success
    assert_select "td", text: users(:lender_admin_user).email
    assert_select "td", { text: users(:admin_user).email, count: 0 }

    get console_users_path(format: :csv)
    assert_not_includes response.body, users(:admin_user).email
  end

  test "non-admins cannot reach the index" do
    sign_in users(:regular_user)
    get console_users_path
    assert_redirected_to root_path
  end
end
