require "test_helper"

class ApplicationSubmissionTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:regular_user)
    sign_in @user
  end

  test "can submit individual ownership application successfully" do
    # Step 1: Visit new application page
    get new_application_path
    assert_response :success
    assert_select "h1", text: "Property Details"

    # Step 2: Verify individual fields are visible in HTML
    assert_select "div[data-application-form-target='individualFields']:not(.js-hidden)"
    assert_select "div[data-application-form-target='jointFields'].js-hidden"
    assert_select "div[data-application-form-target='superFields'].js-hidden"

    # Step 3: Submit property details with individual ownership
    post applications_path, params: {
      application: {
        address: "123 Individual St, Melbourne VIC 3000",
        home_value: 2000000,
        ownership_status: "individual",
        borrower_names: "John Individual",
        borrower_age: 45,
        property_state: "primary_residence",
        has_existing_mortgage: false,
        existing_mortgage_amount: 0
      }
    }

    # Step 4: Verify successful redirect and application creation
    assert_response :redirect
    application = @user.applications.last
    assert_not_nil application
    assert_equal "property_details", application.status
    assert_equal "individual", application.ownership_status
    assert_equal "John Individual", application.borrower_names
    assert_equal 45, application.borrower_age
    assert_equal 2000000, application.home_value
    assert_equal "123 Individual St, Melbourne VIC 3000", application.address

    puts "✅ Individual ownership application successfully created!"
    puts "   - Status: #{application.status}"
    puts "   - Ownership: #{application.ownership_status}"
    puts "   - Borrower: #{application.borrower_names}"
    puts "   - Home Value: $#{application.home_value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end

  test "can submit joint ownership application successfully" do
    # Change to joint ownership
    post applications_path, params: {
      application: {
        address: "456 Joint Ave, Sydney NSW 2000",
        home_value: 1800000,
        ownership_status: "joint",
        borrower_names: '[{"name":"John Joint","age":50},{"name":"Jane Joint","age":48}]',
        property_state: "investment",
        has_existing_mortgage: false
      }
    }

    assert_response :redirect
    application = @user.applications.last
    assert_equal "joint", application.ownership_status
    assert application.borrower_names.present?
    assert_equal 1800000, application.home_value

    puts "✅ Joint ownership application successfully created!"
    puts "   - Status: #{application.status}"
    puts "   - Ownership: #{application.ownership_status}"
    puts "   - Borrowers: #{application.borrower_names}"
  end

  test "can submit superannuation ownership application successfully" do
    # Change to superannuation ownership
    post applications_path, params: {
      application: {
        address: "789 Super St, Brisbane QLD 4000",
        home_value: 2500000,
        ownership_status: "super",
        super_fund_name: "Test Family SMSF",
        property_state: "holiday",
        has_existing_mortgage: false
      }
    }

    assert_response :redirect
    application = @user.applications.last
    assert_equal "super", application.ownership_status
    assert_equal "Test Family SMSF", application.super_fund_name
    assert_equal 2500000, application.home_value

    puts "✅ Superannuation ownership application successfully created!"
    puts "   - Status: #{application.status}"
    puts "   - Ownership: #{application.ownership_status}"
    puts "   - Fund: #{application.super_fund_name}"
  end

  test "validation prevents submission with missing required fields" do
    # Test individual ownership without borrower name
    post applications_path, params: {
      application: {
        address: "123 Test St",
        home_value: 1000000,
        ownership_status: "individual",
        borrower_names: "", # Missing required field
        property_state: "primary_residence"
      }
    }
    assert_response :unprocessable_entity

    # Test joint ownership without borrower names
    post applications_path, params: {
      application: {
        address: "123 Test St",
        home_value: 1000000,
        ownership_status: "joint",
        borrower_names: "", # Missing required field
        property_state: "primary_residence"
      }
    }
    assert_response :unprocessable_entity

    # Test superannuation without fund name
    post applications_path, params: {
      application: {
        address: "123 Test St",
        home_value: 1000000,
        ownership_status: "super",
        super_fund_name: "", # Missing required field
        property_state: "primary_residence"
      }
    }
    assert_response :unprocessable_entity

    puts "✅ Validation correctly prevents invalid submissions!"
  end
end