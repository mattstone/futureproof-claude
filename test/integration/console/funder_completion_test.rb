require "test_helper"

class Console::FunderCompletionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @funder = wholesale_funders(:one)
  end

  test "funder edit captures type, terms and contact; show displays them" do
    patch console_wholesale_funder_path(@funder), params: {
      wholesale_funder: {
        name: @funder.name, country: @funder.country, currency: @funder.currency,
        total_allocated_amount: @funder.total_allocated_amount,
        funding_type: "warehouse",
        contact_name: "Dana Capital", contact_email: "dana@funder.example", contact_phone: "+61 2 9000 0000",
        terms: "Renewal 2027-06-30. Margin review annually."
      }
    }
    assert_redirected_to console_wholesale_funder_path(@funder)

    @funder.reload
    assert @funder.funding_type_warehouse?
    assert_equal "dana@funder.example", @funder.contact_email

    get console_wholesale_funder_path(@funder)
    assert_select ".console-dl-value", text: "Dana Capital"
    assert_match "Warehouse facility", response.body
    assert_match "Renewal 2027-06-30", response.body
  end

  test "onboarding checklist has six steps with contact and document gates" do
    @funder.update_columns(contact_email: nil)
    onboarding = Console::PartnerOnboarding.for(@funder)

    assert_equal 6, onboarding.steps.size
    assert_equal %i[contact agreement documents capital pools lender_access], onboarding.steps.map(&:key)
    assert_not onboarding.steps.find { |s| s.key == :contact }.done

    @funder.update_columns(contact_email: "ops@funder.example")
    assert Console::PartnerOnboarding.for(@funder).steps.find { |s| s.key == :contact }.done

    # The document step reflects the contract library (fixture has one doc)
    assert Console::PartnerOnboarding.for(@funder).steps.find { |s| s.key == :documents }.done
  end

  test "existing funders default to wholesale type untouched" do
    assert @funder.funding_type_wholesale?
  end
end
