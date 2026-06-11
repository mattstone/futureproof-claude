require "test_helper"

class CustomerSupportToolsTest < ActiveSupport::TestCase
  setup do
    @user = users(:john)
    @application = applications(:submitted_application)
    @application.update_columns(user_id: @user.id, region: 'AU')
    @tools = CustomerSupportTools.for(@user)
  end

  test "tool_definitions exposes all three read-only tools" do
    names = CustomerSupportTools.tool_definitions.map { |t| t[:name] }

    assert_includes names, 'get_user_region'
    assert_includes names, 'get_user_applications'
    assert_includes names, 'get_application_status'
  end

  test "rejects calls without an authenticated user" do
    result = CustomerSupportTools.for(nil).call(name: 'get_user_region', input: {})

    assert_match(/Authentication required/, result)
  end

  test "get_user_region returns the user's region" do
    result = @tools.call(name: 'get_user_region', input: {})

    assert_match(/AU/, result)
  end

  test "get_user_applications lists applications" do
    result = @tools.call(name: 'get_user_applications', input: {})

    assert_match(/##{@application.id}/, result)
    assert_match(/status=/, result)
    assert_match(/region=/, result)
  end

  test "get_user_applications says none when user has no applications" do
    other_user = users(:jane)
    result = CustomerSupportTools.for(other_user).call(name: 'get_user_applications', input: {})

    assert_match(/No applications found/i, result)
  end

  test "get_application_status returns blockers" do
    ApplicationDocument.create!(application: @application, document_type: 'identity', status: 'pending')
    ApplicationDocument.create!(application: @application, document_type: 'income_proof', status: 'verified')

    result = @tools.call(name: 'get_application_status', input: { application_id: @application.id })

    assert_match(/Application ##{@application.id}/, result)
    assert_match(/Documents complete: income_proof/, result)
    assert_match(/Documents outstanding: identity/, result)
  end

  test "get_application_status rejects applications not owned by the user" do
    other_user = users(:jane)
    result = CustomerSupportTools.for(other_user).call(name: 'get_application_status', input: { application_id: @application.id })

    assert_match(/not found or not owned/, result)
  end

  test "get_application_status requires application_id" do
    result = @tools.call(name: 'get_application_status', input: {})

    assert_match(/application_id is required/, result)
  end

  test "unknown tools return an error" do
    result = @tools.call(name: 'eval_user_code', input: {})

    assert_match(/Unknown tool/, result)
  end
end
