require "test_helper"

class Console::BrokersAgreementsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @broker = brokers(:one)
  end

  # --- Brokers -------------------------------------------------------------------

  test "broker show renders lender assignments and referrals" do
    get console_broker_path(@broker)

    assert_response :success
    assert_select ".console-card-title", text: "Lender assignments"
    assert_select ".console-card-title", text: "Recent referrals"
  end

  test "broker scorecard renders volume and conversion columns" do
    get scorecard_console_brokers_path
    assert_response :success
    assert_select "td a", text: @broker.name
    assert_select "th", text: "Approval rate"
  end

  test "lender assignment add and remove" do
    lender = Lender.where.not(id: @broker.lender_ids).first
    assert lender, "needs an unassigned lender"

    assert_difference -> { BrokerLender.count }, 1 do
      post assign_lender_console_broker_path(@broker), params: { lender_id: lender.id }
    end

    assert_difference -> { BrokerLender.count }, -1 do
      delete remove_lender_console_broker_path(@broker), params: { lender_id: lender.id }
    end
  end

  test "broker create sends the password setup email" do
    assert_enqueued_emails 1 do
      post console_brokers_path, params: {
        broker: { name: "New Broker Co", email: "new-broker@example.com", jurisdiction: "AU", phone: "0400000000" }
      }
    end
    broker = Broker.find_by(email: "new-broker@example.com")
    assert broker
    assert_redirected_to console_broker_path(broker)
  end

  test "broker toggle active" do
    patch toggle_active_console_broker_path(@broker)
    assert_not @broker.reload.active?
  end

  # --- Agreements ---------------------------------------------------------------------

  test "agreements index shows signature pipeline stats" do
    get console_agreements_path
    assert_response :success
    assert_select ".console-stat-label", text: "Awaiting signature"
    assert_select "td a", text: agreements(:draft_broker_agreement).title
  end

  test "agreement lifecycle: edit draft, send, sign, execute" do
    agreement = agreements(:draft_broker_agreement)

    patch console_agreement_path(agreement), params: { agreement: { title: agreement.title, content: "<p>Updated wording</p>" } }
    assert_redirected_to console_agreement_path(agreement)

    patch send_for_signing_console_agreement_path(agreement)
    assert agreement.reload.status_sent?

    get sign_console_agreement_path(agreement, role: "counterparty")
    assert_response :success

    post record_signature_console_agreement_path(agreement), params: {
      signature: { signer_role: "counterparty", signer_name: "Test Broker", signer_email: "broker@example.com",
                   signer_title: "Director", typed_signature: "Test Broker" }
    }
    assert agreement.reload.status_counterparty_signed?

    post record_signature_console_agreement_path(agreement), params: {
      signature: { signer_role: "futureproof", signer_name: "Matt Stone", signer_email: "matt@futureproof.com",
                   signer_title: "CTO", typed_signature: "Matt Stone" }
    }
    assert agreement.reload.status_fully_executed?
  end

  test "sent agreements cannot be edited" do
    agreement = agreements(:draft_broker_agreement)
    agreement.update_column(:status, Agreement.statuses[:sent])

    patch console_agreement_path(agreement), params: { agreement: { content: "tampered" } }
    assert_redirected_to console_agreement_path(agreement)
    assert_match(/Only draft/, flash[:alert])
    assert_not_equal "tampered", agreement.reload.content
  end

  test "new agreement form offers parties and templates" do
    get new_console_agreement_path(party_type: "Broker")
    assert_response :success
    assert_select "select#agreement_agreeable_id"
    assert_select "select#agreement_legal_document_id"
  end

  test "lender admins are denied" do
    sign_in users(:lender_admin_user)
    get console_brokers_path
    assert_redirected_to console_root_path
    get console_agreements_path
    assert_redirected_to console_root_path
  end
end
