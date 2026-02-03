require "test_helper"

# Get Started Page Tests
# Tests for the React webapp replica at /get-started
class GetStartedPageTest < ActionDispatch::IntegrationTest
  test "get started page loads successfully" do
    get get_started_path
    assert_response :success
  end

  test "get started page has header with alpha banner" do
    get get_started_path
    assert_select ".gs-header"
    assert_select ".gs-alpha-banner"
    assert_select ".gs-alpha-text", /Alpha version/
    assert_select ".gs-header-logo-img"
    assert_select ".gs-header-btn", /Calculate/
  end

  test "get started page has calculator card" do
    get get_started_path
    assert_select ".gs-calc-card"
    assert_select "#property-valuation-card"
    assert_select ".gs-value-amount", minimum: 2  # Home value and monthly income
  end

  test "get started page has EPM logo and branding" do
    get get_started_path
    assert_select ".gs-logo-header"
    assert_select ".gs-logo-title", /Equity Preservation Mortgage/
    assert_select ".gs-logo-subtitle"
  end

  test "get started page has average retiree title" do
    get get_started_path
    assert_select "#average-receive-title"
    assert_select ".gs-avg-title", /maximum annuity income/
    assert_select ".gs-avg-subtitle", /30 year interest-only mortgage/
  end

  test "get started page has term slider" do
    get get_started_path
    assert_select "input.gs-slider[type='range']"
    assert_select ".gs-slider-steps"
    assert_select ".gs-slider-step", 5  # 10, 15, 20, 25, 30 years
    assert_select ".gs-slider-labels"
  end

  test "get started page has features list" do
    get get_started_path
    assert_select ".gs-features-list"
    assert_select ".gs-feature-item", 5
    assert_select ".gs-feature-check", 5
    assert_select ".gs-feature-text", /tax-free monthly annuity income/i
    assert_select ".gs-feature-text", /No depletion of home equity/
    assert_select ".gs-feature-text", /Interest paid on your behalf/
    assert_select ".gs-feature-text", /Equity preserved for intergenerational wealth transfer/
    assert_select ".gs-feature-text", /No sharing of property appreciation/
  end

  test "get started page has freedom cards" do
    get get_started_path
    assert_select ".gs-freedom-card", 4  # Flexibility, Wealth, Joy, Inheritance
    assert_select ".gs-freedom-subtitle", /Flexibility/
    assert_select ".gs-freedom-subtitle", /Wealth/
    assert_select ".gs-freedom-subtitle", /Joy/
    assert_select ".gs-freedom-subtitle", /Inheritance/
  end

  test "get started page has partners section" do
    get get_started_path
    assert_select ".gs-partners"
    assert_select ".gs-partners-title", /trusted partners/i
    assert_select ".gs-partner-logo", minimum: 5
  end

  test "get started page has CTA buttons" do
    get get_started_path
    assert_select ".gs-cta-btn", minimum: 2
    assert_select ".gs-cta-btn", /Calculate how much you could receive/
  end

  test "get started page has modal for home value change" do
    get get_started_path
    assert_select ".gs-modal-overlay"
    assert_select ".gs-modal-title", /home valuation/i
    assert_select ".gs-modal-save-btn", /Save/
    assert_select ".gs-input-hint", /Minimum amount is \$800,000/
  end

  test "get started page has proper footer" do
    get get_started_path
    assert_select ".gs-footer"
    assert_select ".gs-footer-main"
    assert_select ".gs-footer-bottom"
    assert_select ".gs-footer-disclaimer", minimum: 1
    assert_select ".gs-footer-copyright"
    assert_select ".gs-footer-link", minimum: 6
  end

  test "get started page has promo card" do
    get get_started_path
    assert_select ".gs-promo-card"
    assert_select ".gs-promo-image"
    assert_select ".gs-promo-buttons"
    assert_select ".gs-btn-outline", /Learn more/
    assert_select ".gs-btn-primary", /Calculate now/
  end

  test "get started page loads without authentication" do
    # Should be accessible without being logged in
    get get_started_path
    assert_response :success
    # Should not redirect to login
    assert_not_equal new_user_session_path, path
  end

  test "get started page has change button for home value" do
    get get_started_path
    assert_select ".gs-change-btn", /Change/
    assert_select "[data-action='click->get-started-calculator#openModal']"
  end

  test "get started page has Stimulus controller data attributes" do
    get get_started_path
    assert_select "[data-controller='get-started-calculator']"
    assert_select "[data-get-started-calculator-target='homeValue']"
    assert_select "[data-get-started-calculator-target='monthlyIncome']"
    assert_select "[data-get-started-calculator-target='termDisplay']"
    assert_select "[data-get-started-calculator-target='termSlider']"
    assert_select "[data-get-started-calculator-target='modal']"
    assert_select "[data-get-started-calculator-target='modalInput']"
  end

  test "get started page has hero section with image" do
    get get_started_path
    assert_select ".gs-hero"
    assert_select ".gs-hero-image"
  end

  test "get started page has content section that overlays hero" do
    get get_started_path
    assert_select ".gs-content"
    assert_select ".gs-content .gs-calc-card"
  end

  # Create Account Modal Tests (matches React webapp /application/create-account)
  test "get started page has email modal for create account flow" do
    get get_started_path
    assert_select ".gs-email-modal"
    assert_select ".gs-modal-title", /Let's begin/
    assert_select ".gs-modal-description", /To access the calculator please enter your email address/
  end

  test "get started page email modal has email input" do
    get get_started_path
    assert_select "input#gs-email-input[type='email']"
    assert_select "input[data-get-started-calculator-target='emailInput']"
    assert_select ".gs-input-label", /Your email address/
  end

  test "get started page email modal has terms checkbox" do
    get get_started_path
    assert_select ".gs-terms-checkbox"
    assert_select "input.gs-checkbox[type='checkbox']"
    assert_select ".gs-terms-text", /terms and conditions/
    assert_select "a.gs-terms-link", /terms and conditions/
  end

  test "get started page email modal has continue button" do
    get get_started_path
    assert_select "button.gs-continue-btn[disabled]", /Continue/
    assert_select "[data-testid='email-form-continue-button']"
  end

  test "get started page CTA buttons trigger email modal" do
    get get_started_path
    # Header button
    assert_select "button.gs-header-btn[data-action='click->get-started-calculator#openEmailModal']", /Calculate/
    # Main CTA buttons
    assert_select "button.gs-cta-btn[data-action='click->get-started-calculator#openEmailModal']", /Calculate how much you could receive/
    # Promo card button
    assert_select "button.gs-btn-primary[data-action='click->get-started-calculator#openEmailModal']", /Calculate now/
  end
end
