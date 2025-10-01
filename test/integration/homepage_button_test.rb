require "test_helper"

class HomepageButtonTest < ActionDispatch::IntegrationTest
  test "homepage renders with Apply Now button properly styled" do
    get root_path
    assert_response :success
    
    # Check that Apply Now button exists
    assert_select "a.calc-apply-button", text: /Apply Now/
    
    # Verify the button has correct href
    assert_select "a.calc-apply-button[href=?]", apply_path
  end
  
  test "homepage CSS loads correctly" do
    get root_path
    assert_response :success
    
    # Check that homepage uses the homepage class
    assert_select "div.homepage"
    
    # Check that calculator card exists
    assert_select "div.hero-calculator-card"
    
    # Check that button is inside calculator card
    assert_select "div.hero-calculator-card a.calc-apply-button"
  end
end
