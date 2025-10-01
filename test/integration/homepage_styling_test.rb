require "test_helper"

class HomepageStylingTest < ActionDispatch::IntegrationTest
  test "homepage loads without errors" do
    get root_path
    assert_response :success
    puts "✓ Homepage loads successfully"
  end
  
  test "Apply Now button renders correctly" do
    get root_path
    assert_response :success
    
    # Check button exists
    assert_select "a.calc-apply-button" do |elements|
      assert_equal 1, elements.length, "Should have exactly one Apply Now button"
      puts "✓ Apply Now button exists"
    end
    
    # Check button is inside calculator card
    assert_select "div.hero-calculator-card a.calc-apply-button"
    puts "✓ Button is inside calculator card"
    
    # Check button links to correct path
    assert_select "a.calc-apply-button[href='#{apply_path}']"
    puts "✓ Button links to #{apply_path}"
  end
  
  test "hero section structure is correct" do
    get root_path
    assert_response :success
    
    # Check hero structure
    assert_select "section.hero-fullscreen"
    puts "✓ Hero fullscreen section exists"
    
    assert_select "div.hero-two-column"
    puts "✓ Two column layout exists"
    
    assert_select "div.hero-left-column"
    puts "✓ Left column exists"
    
    assert_select "div.hero-right-column"
    puts "✓ Right column exists"
    
    assert_select "div.hero-calculator-card"
    puts "✓ Calculator card exists"
  end
  
  test "CSS file is loaded" do
    get root_path
    assert_response :success
    
    # The response should include the homepage CSS
    response_body = @response.body
    assert response_body.include?("homepage"), "Response should reference homepage CSS"
    puts "✓ Homepage CSS is referenced in page"
  end
end
