require "test_helper"

class Console::ComplianceTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @application = applications(:submitted_application)
    @kyc = KycSubmission.create!(application: @application, status: :submitted, verification_type: "government_id",
                                 document_url: "https://example.com/doc.pdf", submitted_at: 1.day.ago)
    @aml = AmlCheck.create!(application: @application, status: :checking, checked_at: 1.day.ago)
  end

  test "cockpit shows compliance actions and the approval warning" do
    get console_application_path(@application)

    assert_response :success
    assert_select "form[action=?]", verify_kyc_console_application_path(@application)
    assert_select "form[action=?]", fail_aml_console_application_path(@application)
    assert_match(/Compliance incomplete/, response.body)
  end

  test "verify kyc records the decision maker and audits" do
    assert_difference -> { AuditLog.where(action: "kyc_verified").count }, 1 do
      patch verify_kyc_console_application_path(@application)
    end

    @kyc.reload
    assert @kyc.verified?
    assert_equal users(:admin_user).display_name, @kyc.verified_by
  end

  test "reject kyc requires a reason" do
    patch reject_kyc_console_application_path(@application)
    assert_match(/reason is required/, flash[:alert])
    assert_not @kyc.reload.rejected?

    patch reject_kyc_console_application_path(@application), params: { reason: "Document illegible" }
    assert @kyc.reload.rejected?
  end

  test "aml pass and fail flows audit" do
    assert_difference -> { AuditLog.where(action: "aml_passed").count }, 1 do
      patch pass_aml_console_application_path(@application)
    end
    assert @aml.reload.passed?

    @aml.update_columns(status: AmlCheck.statuses[:checking])
    assert_difference -> { AuditLog.where(action: "aml_failed").count }, 1 do
      patch fail_aml_console_application_path(@application), params: { reason: "Sanctions list match" }
    end
    assert @aml.reload.failed?
    assert_equal "Sanctions list match", @aml.failure_reason
  end

  test "warning clears once both checks are green" do
    @kyc.update_columns(status: KycSubmission.statuses[:verified])
    @aml.update_columns(status: AmlCheck.statuses[:passed])

    get console_application_path(@application)
    assert_no_match(/Compliance incomplete/, response.body)
  end

  test "actions on applications without records fail gracefully" do
    bare = applications(:processing_application)
    bare.kyc_submission&.destroy

    patch verify_kyc_console_application_path(bare)
    assert_match(/No KYC record/, flash[:alert])
  end
end
