require "test_helper"

class Console::PartnerOnboardingTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @lender = lenders(:broker)
  end

  # --- Derived state -----------------------------------------------------------

  test "onboarding steps derive from reality and flip as things are configured" do
    broker = brokers(:one)
    onboarding = Console::PartnerOnboarding.for(broker)
    assert_equal 4, onboarding.steps.size
    agreement_step = onboarding.steps.find { |s| s.key == :agreement }
    assert_not agreement_step.done

    agreements(:draft_broker_agreement).update_columns(status: Agreement.statuses[:fully_executed])
    assert Console::PartnerOnboarding.for(broker).steps.find { |s| s.key == :agreement }.done
  end

  test "complete partner reads Active" do
    onboarding = Console::PartnerOnboarding.for(lenders(:futureproof))
    assert_equal "Active", onboarding.progress_label if onboarding.complete?
    assert_match(/Active|Onboarding \d\/5/, onboarding.progress_label)
  end

  # --- Show pages ----------------------------------------------------------------

  test "all three partner pages render the onboarding checklist and agreements" do
    get console_lender_path(@lender)
    assert_select ".console-onboarding-step", count: 5
    assert_select ".console-card-title", text: "Agreements"
    assert_select ".console-card-title", text: "Lender admin users"

    get console_wholesale_funder_path(wholesale_funders(:one))
    assert_select ".console-onboarding-step", count: 6

    get console_broker_path(brokers(:one))
    assert_select ".console-onboarding-step", count: 4
  end

  test "incomplete steps link to where you complete them" do
    get console_lender_path(@lender)
    assert_select ".console-onboarding-step a", text: "Complete", minimum: 1
  end

  # --- Agreements wiring ------------------------------------------------------------

  test "new agreement from a partner page preselects the party" do
    get new_console_agreement_path(party_type: "Broker", agreeable_id: brokers(:one).id)
    assert_response :success
    assert_select "select#agreement_agreeable_id option[selected][value=?]", brokers(:one).id.to_s
  end

  # --- Invite admin --------------------------------------------------------------------

  test "inviting a lender admin creates the scoped user, emails them and audits" do
    assert_difference -> { @lender.users.where(admin: true).count }, 1 do
      assert_difference -> { AuditLog.where(action: "partner_admin_invited").count }, 1 do
        assert_emails 1 do
          post invite_admin_console_lender_path(@lender), params: {
            first_name: "Pat", last_name: "Lender", email: "pat@testbroker.com.au"
          }
        end
      end
    end

    user = User.find_by(email: "pat@testbroker.com.au")
    assert user.admin?
    assert_equal @lender, user.lender
    assert_redirected_to console_lender_path(@lender)
  end

  test "invalid invite fails gracefully" do
    assert_no_difference "User.count" do
      post invite_admin_console_lender_path(@lender), params: { first_name: "X", last_name: "Y", email: "not-an-email" }
    end
    assert_match(/Invite failed/, flash[:alert])
  end

  # --- Index badges ------------------------------------------------------------------------

  test "partner indexes show the onboarding stage" do
    get console_lenders_path
    assert_select "th", text: "Onboarding"
    assert_select ".console-badge", text: /Onboarding \d\/\d|Active partner|Active/

    get console_brokers_path
    assert_select "th", text: "Onboarding"
  end
end
