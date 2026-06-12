require "test_helper"

class Console::LenderCompletionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @lender = lenders(:broker)
  end

  # --- Record completeness -------------------------------------------------------

  test "edit captures licence and contact name; show displays them with the regulator" do
    patch console_lender_path(@lender), params: {
      lender: {
        name: @lender.name, lender_type: @lender.lender_type, country: "AU",
        contact_email: @lender.contact_email,
        licence_ref: "AFSL 519384", contact_name: "Robin Marsh"
      }
    }
    assert_redirected_to console_lender_path(@lender)

    @lender.reload
    assert_equal "AFSL 519384", @lender.licence_ref

    get console_lender_path(@lender)
    assert_select ".console-dl-value", text: "AFSL 519384"
    assert_select ".console-dl-value", text: "Robin Marsh"
    assert_match "Australian Securities and Investments Commission", response.body
  end

  # --- Book ----------------------------------------------------------------------

  test "book card shows capacity, contracts and the recent applications" do
    application = @lender.applications.order(created_at: :desc).first ||
                  Application.create!(user: users(:regular_user), lender: @lender,
                                      address: "1 Test St", home_value: 900_000, status: :submitted,
                                      ownership_status: :individual, property_state: :primary_residence,
                                      borrower_age: 65)

    get console_lender_path(@lender)
    assert_select ".console-card-title", text: "Book"
    assert_select ".console-dl-term", text: "Pool capacity"
    assert_select ".console-dl-term", text: "Active contracts"
    assert_select ".console-dl-term", text: "Applications in pipeline"
    assert_select "a", text: "Application ##{application.id}"
  end

  # --- Products ------------------------------------------------------------------

  test "products card manages mortgage assignments from the lender side" do
    mortgage = Mortgage.where.not(id: @lender.mortgage_ids).first ||
               Mortgage.create!(name: "LN1 Test Product", mortgage_type: :interest_only, lvr: 80)

    assert_difference -> { @lender.mortgage_lenders.count }, 1 do
      post add_product_console_lender_path(@lender), params: { mortgage_id: mortgage.id }
    end
    assert_redirected_to console_lender_path(@lender)

    get console_lender_path(@lender)
    assert_select ".console-card-title", text: "Products offered"
    assert_select "a", text: mortgage.name

    relationship = @lender.mortgage_lenders.find_by(mortgage: mortgage)
    patch toggle_active_console_mortgage_mortgage_lender_path(mortgage, relationship),
          headers: { "HTTP_REFERER" => console_lender_path(@lender) }
    assert_redirected_to console_lender_path(@lender)
    assert_not relationship.reload.active?
  end

  test "duplicate product assignment is rejected gracefully" do
    mortgage = Mortgage.create!(name: "LN1 Dup Product", mortgage_type: :interest_only, lvr: 80)
    MortgageLender.create!(mortgage: mortgage, lender: @lender, active: true)

    assert_no_difference -> { MortgageLender.count } do
      post add_product_console_lender_path(@lender), params: { mortgage_id: mortgage.id }
    end
    assert_match(/already associated/, flash[:alert])
  end

  # --- Broker channel ------------------------------------------------------------

  test "broker channel card lists assigned brokers with referral counts" do
    broker = brokers(:one)
    BrokerLender.find_or_create_by!(broker: broker, lender: @lender) { |bl| bl.active = true }
    referrals = @lender.applications.where(broker_id: broker.id).count

    get console_lender_path(@lender)
    assert_select ".console-card-title", text: "Broker channel"
    assert_select "a", text: broker.name
    assert_match pluralize(referrals, "referral"), response.body
  end

  # --- Onboarding ----------------------------------------------------------------

  test "onboarding checklist has five steps gated on the licence" do
    @lender.update_columns(licence_ref: nil)
    onboarding = Console::PartnerOnboarding.for(@lender)

    assert_equal 5, onboarding.steps.size
    assert_equal %i[licence agreement admin_user funding product], onboarding.steps.map(&:key)
    assert_not onboarding.steps.find { |s| s.key == :licence }.done

    @lender.update_columns(licence_ref: "AFSL 000111")
    assert Console::PartnerOnboarding.for(@lender).steps.find { |s| s.key == :licence }.done
  end

  private

  def pluralize(count, word)
    ActionController::Base.helpers.pluralize(count, word)
  end
end
