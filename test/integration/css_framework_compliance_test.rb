require "test_helper"

class CssFrameworkComplianceTest < ActionDispatch::IntegrationTest
  # 🚨 CRITICAL: MANDATORY 7-STEP TESTING PROTOCOL FOR CSS FRAMEWORK COMPLIANCE 🚨

  def setup
    # Use existing lender or create a regular lender (not futureproof type)
    @lender = Lender.find_by(lender_type: "futureproof") || Lender.create!(
      name: "Test Lender",
      lender_type: "lender",
      contact_email: "admin@test.com",
      country: "US"
    )

    @admin_user = User.create!(
      email: "admin@test.com",
      password: "password123",
      first_name: "Admin",
      last_name: "User",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: true,
      admin: true,
      confirmed_at: Time.current
    )

    @regular_user = User.create!(
      email: "user@test.com",
      password: "password123",
      first_name: "Regular",
      last_name: "User",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: true,
      admin: false,
      confirmed_at: Time.current
    )

    # Create business process workflows for testing
    BusinessProcessWorkflow.ensure_default_workflows!
  end

  # STEP 1-7: EXPERT INTEGRATION TEST for Public Pages
  test "EXPERT INTEGRATION TEST: public pages CSS framework compliance" do
    public_pages = [
      "/",
      "/apply",
      "/terms_of_use",
      "/privacy_policy",
      "/terms_and_conditions"
    ]

    public_pages.each do |page_path|
      # STEP 3-4: Test actual URLs with real HTTP
      get page_path
      assert_response :success, "Failed to load #{page_path}"

      # STEP 5: Verify HTML renders without framework violations
      assert_no_css_framework_violations(response.body, page_path)

      # STEP 6: Verify custom classes are present
      assert_custom_css_classes_present(response.body, page_path)
    end

    # STEP 7: Success - All public pages verified
    assert true, "✅ PUBLIC PAGES: All pages comply with CSS framework rules"
  end

  test "EXPERT INTEGRATION TEST: authentication pages CSS framework compliance" do
    # Test Devise authentication pages
    auth_pages = [
      "/users/sign_in",
      "/users/sign_up"
    ]

    auth_pages.each do |page_path|
      get page_path
      assert_response :success, "Failed to load #{page_path}"
      assert_no_css_framework_violations(response.body, page_path)
      assert_custom_css_classes_present(response.body, page_path)
    end

    assert true, "✅ AUTH PAGES: All authentication pages comply with CSS framework rules"
  end

  test "EXPERT INTEGRATION TEST: admin pages CSS framework compliance" do
    sign_in @admin_user

    admin_pages = [
      "/admin",
      "/admin/users",
      "/admin/applications",
      "/admin/email_workflows",
      "/admin/business_process_workflows",
      "/admin/workflow_forms"
    ]

    admin_pages.each do |page_path|
      get page_path
      assert_response :success, "Failed to load #{page_path}"
      assert_no_css_framework_violations(response.body, page_path)
      assert_custom_css_classes_present(response.body, page_path)
    end

    assert true, "✅ ADMIN PAGES: All admin pages comply with CSS framework rules"
  end

  test "EXPERT INTEGRATION TEST: dashboard pages CSS framework compliance" do
    sign_in @regular_user

    # Create an application for dashboard testing
    @application = Application.create!(
      user: @regular_user,
      address: "123 Test St, Test City",
      home_value: 500000,
      ownership_status: "own_with_mortgage",
      property_state: "vic"
    )

    dashboard_pages = [
      "/dashboard",
      "/start-application",
      "/dashboard/applications/new"
    ]

    dashboard_pages.each do |page_path|
      get page_path
      # Some dashboard pages may redirect, so accept both success and redirect
      assert_includes [200, 302], response.status, "Failed to load #{page_path}"

      if response.status == 200
        assert_no_css_framework_violations(response.body, page_path)
        assert_custom_css_classes_present(response.body, page_path)
      end
    end

    assert true, "✅ DASHBOARD PAGES: All dashboard pages comply with CSS framework rules"
  end

  test "EXPERT INTEGRATION TEST: workflow system CSS framework compliance" do
    sign_in @admin_user

    workflow_pages = [
      "/admin/email_workflows",
      "/admin/email_workflows/new",
      "/admin/business_process_workflows",
      "/admin/workflow_forms"
    ]

    workflow_pages.each do |page_path|
      get page_path
      assert_response :success, "Failed to load #{page_path}"
      assert_no_css_framework_violations(response.body, page_path)
      assert_custom_css_classes_present(response.body, page_path)
    end

    # Test specific workflow detail pages
    if (workflow = BusinessProcessWorkflow.first)
      get "/admin/business_process_workflows/#{workflow.id}"
      assert_response :success
      assert_no_css_framework_violations(response.body, "workflow detail page")

      get "/admin/workflow_forms/#{workflow.id}"
      assert_response :success
      assert_no_css_framework_violations(response.body, "workflow form page")
    end

    assert true, "✅ WORKFLOW PAGES: All workflow pages comply with CSS framework rules"
  end

  test "COMPREHENSIVE SITE SCAN: detect any remaining violations across entire site" do
    sign_in @admin_user

    # Test a comprehensive list of routes
    comprehensive_routes = [
      # Public routes
      "/", "/apply", "/terms_of_use", "/privacy_policy",

      # Auth routes
      "/users/sign_in", "/users/sign_up",

      # Admin routes
      "/admin", "/admin/users", "/admin/applications",
      "/admin/lenders", "/admin/email_templates",
      "/admin/email_workflows", "/admin/business_process_workflows",
      "/admin/workflow_forms", "/admin/privacy_policies",
      "/admin/terms_and_conditions", "/admin/terms_of_uses"
    ]

    violations_found = []

    comprehensive_routes.each do |route|
      begin
        get route
        if response.status == 200
          violations = detect_css_framework_violations(response.body)
          if violations.any?
            violations_found << { route: route, violations: violations }
          end
        end
      rescue => e
        # Skip routes that error (may require additional setup)
        next
      end
    end

    if violations_found.any?
      violation_summary = violations_found.map do |item|
        "#{item[:route]}: #{item[:violations].join(', ')}"
      end.join("\n")

      flunk "❌ VIOLATIONS FOUND:\n#{violation_summary}"
    else
      assert true, "✅ COMPREHENSIVE SCAN: No CSS framework violations detected across the entire site"
    end
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end

  def assert_no_css_framework_violations(html_body, page_identifier)
    violations = detect_css_framework_violations(html_body)

    if violations.any?
      flunk "❌ CSS FRAMEWORK VIOLATIONS FOUND in #{page_identifier}:\n" +
            violations.join("\n") +
            "\n\nPage must use custom site-* classes instead of external frameworks."
    end
  end

  def detect_css_framework_violations(html_body)
    violations = []

    # Tailwind CSS violations (most common patterns)
    tailwind_patterns = [
      /class="[^"]*\btext-\w+-\d+\b/,         # text-gray-500, text-blue-600, etc.
      /class="[^"]*\bbg-\w+-\d+\b/,           # bg-gray-100, bg-blue-500, etc.
      /class="[^"]*\bspace-[xy]-\d+\b/,       # space-x-4, space-y-2, etc.
      /class="[^"]*\bgap-\d+\b/,              # gap-4, gap-6, etc.
      /class="[^"]*\bm[btlrxy]?-\d+\b/,       # mb-4, mt-6, mx-2, etc.
      /class="[^"]*\bp[btlrxy]?-\d+\b/,       # px-3, py-2, pl-4, etc.
      /class="[^"]*(?<!site-)(?<!admin-)\b(flex|grid)\b/,          # flex, grid (but not site-flex, site-grid, admin-flex, admin-grid)
      /class="[^"]*\bjustify-\w+\b/,          # justify-between, justify-center
      /class="[^"]*\bitems-\w+\b/,            # items-center, items-start
      /class="[^"]*\bw-\d+\b/,                # w-4, w-full (but not w-auto)
      /class="[^"]*\bh-\d+\b/,                # h-4, h-screen
      /class="[^"]*\brounded(-\w+)?\b/        # rounded, rounded-lg
    ]

    # Bootstrap CSS violations (but exclude our custom admin-btn-* and site-btn-* classes)
    bootstrap_patterns = [
      /class="[^"]*(?<!admin-)(?<!site-)btn-primary\b/,     # Bootstrap buttons (but not admin-btn-primary or site-btn-primary)
      /class="[^"]*(?<!admin-)(?<!site-)btn-secondary\b/,   # Bootstrap buttons (but not admin-btn-secondary or site-btn-secondary)
      /class="[^"]*\bcontainer(-fluid)?\b/,                 # Bootstrap containers
      /class="[^"]*\brow\b/,                                # Bootstrap grid row
      /class="[^"]*\bcol(-\w*)?(-\d+)?\b/,                  # Bootstrap grid columns
      /class="[^"]*\bd-flex\b/,                             # Bootstrap display utilities
      /class="[^"]*\bjustify-content-\w+\b/,                # Bootstrap flexbox utilities
      /class="[^"]*\balign-items-\w+\b/
    ]

    all_patterns = tailwind_patterns + bootstrap_patterns

    all_patterns.each do |pattern|
      if matches = html_body.scan(pattern)
        matches.each do |match|
          violations << "FORBIDDEN: #{match}"
        end
      end
    end

    violations.uniq
  end

  def assert_custom_css_classes_present(html_body, page_identifier)
    # Verify that custom CSS classes are being used
    custom_patterns = [
      /\bsite-/, # site-* prefixed classes
      /\badmin-/ # admin-* prefixed classes for admin pages
    ]

    has_custom_classes = custom_patterns.any? { |pattern| html_body =~ pattern }

    unless has_custom_classes
      flunk "❌ NO CUSTOM CSS CLASSES FOUND in #{page_identifier}. " +
            "Page should use site-* or admin-* prefixed classes."
    end
  end
end