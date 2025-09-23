require 'test_helper'

class RegistrationDebuggingTest < ActionDispatch::IntegrationTest
  test "debug registration process step by step" do
    # First verify we can access the signup page
    get "/users/sign_up"
    assert_response :success

    # Check if the form is there
    assert_select "form[action='/users']"

    # Try to submit and capture any errors
    post "/users", params: {
      user: {
        first_name: "Debug",
        last_name: "Test",
        email: "debug.test@example.com",
        password: "password123",
        password_confirmation: "password123",
        country_of_residence: "Australia",
        terms_accepted: "1"
      }
    }

    # Print response details for debugging
    puts "\n=== Registration Response Debug ==="
    puts "Status: #{response.status}"
    puts "Headers: #{response.headers.slice('Content-Type', 'Location')}"

    if response.status == 422
      puts "Validation errors detected"
      # Look for specific error content
      if response.body.include?("field_with_errors")
        puts "Found field_with_errors in response"
      end
      if response.body.include?("error_explanation")
        puts "Found error_explanation in response"
      end
    end

    # Check what happened to user creation
    user = User.find_by(email: "debug.test@example.com")
    if user
      puts "User was created: #{user.id}"
      puts "Applications count: #{user.applications.count}"
    else
      puts "User was NOT created"
    end

    puts "=== End Debug ==="
  end

  test "manual user creation works correctly" do
    # Test that our model changes work in isolation
    user = nil
    application = nil

    assert_difference ['User.count', 'Application.count'], 1 do
      user = User.create!(
        first_name: "Manual",
        last_name: "Test",
        email: "manual.test@example.com",
        password: "password123",
        country_of_residence: "Australia",
        terms_accepted: true
      )
    end

    assert_not_nil user
    assert_equal 1, user.applications.count

    application = user.applications.first
    assert application.status_created?
    assert_nil application.address
    assert application.valid?
  end
end