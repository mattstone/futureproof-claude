require "test_helper"

# Covers the two newest pieces of the quote/application flow:
# 1. Versioned quote snapshots — every completed income & mortgage step
#    persists an immutable Quote pinned to the product version that priced it.
# 2. UK adviser-led gating — FCA MCOB prohibits execution-only sales of
#    lifetime mortgages, so UK users never see the self-service flow.
class QuoteVersioningAndUkGatingTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:regular_user)
    @uk_user = users(:uk_user)
    @mortgage = mortgages(:interest_only)
  end

  def create_application(user)
    user.applications.create!(
      address: "1 Test Street, Sydney NSW 2000",
      home_value: 1_500_000,
      ownership_status: "individual",
      property_state: "primary_residence",
      has_existing_mortgage: false,
      borrower_age: 65,
      status: :property_details
    )
  end

  test "completing the income and mortgage step persists a versioned quote" do
    sign_in @user
    application = create_application(@user)

    assert_difference -> { Quote.count }, 1 do
      patch update_income_and_loan_application_path(application), params: {
        application: { loan_term: 30, income_payout_term: 10, mortgage_id: @mortgage.id, growth_rate: 3.0 }
      }
    end
    assert_redirected_to summary_application_path(application)

    quote = application.quotes.latest_first.first
    assert_equal EpmModelConfig.model_version, quote.product_version
    assert_equal 1_500_000, quote.home_value
    assert_equal 30, quote.term_years
    assert_equal 10, quote.income_payout_term
    assert_equal "AU", quote.region
    assert quote.monthly_income.to_i.positive?
    assert quote.issued_at.present?
  end

  test "persisted quotes are immutable" do
    application = create_application(@user)
    quote = Quote.create!(
      application: application,
      product_version: EpmModelConfig.model_version,
      home_value: 1_500_000,
      term_years: 30,
      monthly_income: 2_500,
      issued_at: Time.current
    )

    assert_raises(ActiveRecord::ReadOnlyRecord) { quote.update!(monthly_income: 9_999) }
  end

  test "UK users are shown the adviser-led notice instead of the self-service flow" do
    sign_in @uk_user

    get new_application_path
    assert_response :success
    assert_select "h1", text: /Speak to a Qualified Adviser/
    assert_select 'input[name="application[address]"]', count: 0
  end

  test "UK applications fail jurisdiction validation for self-service submission" do
    application = create_application(@user)
    errors = EpmJurisdictionService.new("UK").validate_application(application)

    assert errors.any? { |e| e.include?("qualified adviser") },
           "Expected adviser-led error, got: #{errors.inspect}"
  end

  test "self-service regions are not gated" do
    sign_in @user

    get new_application_path
    assert_response :success
    assert_select "h1", text: /Speak to a Qualified Adviser/, count: 0
  end
end
