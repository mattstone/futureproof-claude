require 'test_helper'

class MortgageContractLivePreviewTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      first_name: "Admin",
      last_name: "User",
      email: "admin@futureproof.app",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )
    
    @lender = Lender.create!(
      name: "Futureproof Financial Group",
      contact_email: "contact@futureproof.app",
      lender_type: :futureproof
    )
    
    @admin.update!(lender: @lender)
    
    @mortgage = Mortgage.create!(
      name: "Test Mortgage",
      mortgage_type: :interest_only,
      lvr: 80.0
    )
    
    @mortgage_contract = @mortgage.mortgage_contracts.create!(
      title: "Test Contract",
      content: build_sample_content,
      is_draft: true,
      created_by: @admin
    )
  end
  
  test "edit page includes live preview JavaScript and CSS" do
    sign_in @admin
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    
    # Should include the JavaScript for live preview
    assert_select "script", text: /initializeMortgageContractPreview/
    assert_select "script", text: /markupToHtml/
    assert_select "script", text: /updatePreviewInstant/
    
    # Should include CSS for live preview layout
    assert_select "style", text: /\.contract-editor-layout/
    assert_select "style", text: /\.contract-preview-column/
    assert_select "style", text: /\.markup-preview/
    
    # Should have the required HTML structure
    assert_select ".contract-editor-layout"
    assert_select ".contract-form-column"
    assert_select ".contract-preview-column"
    assert_select "#markup-preview-standalone"
    assert_select "textarea.markup-editor"
  end
  
  test "JavaScript includes proper markup conversion functions" do
    sign_in @admin
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    
    response_body = @response.body
    
    # Should include markup processing patterns
    assert response_body.include?("sections.forEach")
    assert response_body.include?("legal-section")
    assert response_body.include?("loan-details")
    assert response_body.include?("contact-info")
    assert response_body.include?("### (.+)$")
    assert response_body.include?("^- (.+)$")
    assert response_body.include?("**(.+?):**")
    
    # Should include event listeners
    assert response_body.include?("addEventListener('input'")
    assert response_body.include?("addEventListener('keydown'")
    
    # Should include initialization strategies
    assert response_body.include?("DOMContentLoaded")
    assert response_body.include?("MutationObserver")
    assert response_body.include?("setTimeout")
  end
  
  test "preview functionality handles various markup patterns" do
    sign_in @admin
    
    # Test different markup content through preview endpoint
    test_cases = [
      {
        name: "Basic sections",
        content: "## Section 1\n\nBasic paragraph.\n\n## Section 2\n\nAnother paragraph.",
        expected_html: ["<h2>Section 1</h2>", "<h2>Section 2</h2>", "<p>Basic paragraph.</p>"]
      },
      {
        name: "Subsections and lists", 
        content: "## Main\n\n### Sub\n\n- Item 1\n- Item 2",
        expected_html: ["<h2>Main</h2>", "<h3>Sub</h3>", "<ul>", "<li>Item 1</li>", "<li>Item 2</li>"]
      },
      {
        name: "Loan details",
        content: "## Details\n\n**Loan Amount:** $500,000\n**Rate:** 4.5%",
        expected_html: ["<div class=\"loan-details\">", "<strong>Loan Amount:</strong>", "<span>$500,000</span>"]
      },
      {
        name: "Contact information",
        content: "## Contact\n\nLender: Test Lender\nEmail: test@example.com\nPhone: 123-456-7890",
        expected_html: ["<div class=\"contact-info\">", "<strong>Test Lender</strong>", "Email: test@example.com"]
      },
      {
        name: "Bold text",
        content: "## Test\n\nThis is **bold text** in a paragraph.",
        expected_html: ["<strong>bold text</strong>", "<p>This is"]
      }
    ]
    
    test_cases.each do |test_case|
      post preview_admin_mortgage_mortgage_contracts_path(@mortgage), params: {
        mortgage_contract: {
          title: "Test",
          content: test_case[:content]
        }
      }
      
      assert_response :success, "Failed for test case: #{test_case[:name]}"
      
      test_case[:expected_html].each do |expected|
        assert @response.body.include?(expected), 
               "Expected '#{expected}' in response for test case: #{test_case[:name]}\nActual response: #{@response.body}"
      end
    end
  end
  
  test "JavaScript handles special characters and sanitization" do
    sign_in @admin
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    
    # Should include sanitization function
    assert @response.body.include?("sanitizeText")
    assert @response.body.include?("replace(/[<>\"]")
    
    # Test through preview endpoint with dangerous content
    post preview_admin_mortgage_mortgage_contracts_path(@mortgage), params: {
      mortgage_contract: {
        title: "Test <script>alert('xss')</script>",
        content: "## Test\n\nContent with <script>alert('xss')</script> and \"quotes\"."
      }
    }
    
    assert_response :success
    
    # Should not contain script tags
    assert_not @response.body.include?("<script>alert('xss')</script>")
    # Should contain sanitized version
    assert @response.body.include?("scriptalert('xss')/script")
  end
  
  test "responsive CSS is included for mobile support" do
    sign_in @admin
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    
    # Should include responsive CSS
    assert_select "style", text: /@media \(max-width: 1400px\)/
    assert_select "style", text: /@media \(max-width: 1200px\)/
    assert_select "style", text: /grid-template-columns: 1fr/
    assert_select "style", text: /position: static/
  end
  
  test "preview functionality includes full page preview support" do
    sign_in @admin
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    
    # Should include full page preview functionality
    assert @response.body.include?("Full page preview functionality")
    assert @response.body.include?("tempForm.action = form.action.replace")
    assert @response.body.include?("tempForm.target = '_blank'")
    assert @response.body.include?("mortgage_contract[title]")
    assert @response.body.include?("mortgage_contract[content]")
  end
  
  test "JavaScript initialization handles various loading scenarios" do
    sign_in @admin
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    
    response_body = @response.body
    
    # Should include multiple initialization strategies
    assert response_body.include?("DOMContentLoaded"), "Should handle DOMContentLoaded"
    assert response_body.include?("window.addEventListener('load'"), "Should handle window load"
    assert response_body.include?("MutationObserver"), "Should handle dynamic content"
    assert response_body.include?("setTimeout"), "Should handle delayed initialization"
    
    # Should include checks for already initialized
    assert response_body.include?("isAlreadyInitialized"), "Should prevent double initialization"
    assert response_body.include?("data-preview-initialized"), "Should mark as initialized"
    
    # Should stop observer to prevent memory leaks
    assert response_body.include?("observer.disconnect()"), "Should cleanup observers"
    assert response_body.include?("10000"), "Should have timeout for cleanup"
  end
  
  test "live preview supports tab key handling for indentation" do
    sign_in @admin
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    
    # Should include tab key handling
    assert @response.body.include?("if (e.key === 'Tab')")
    assert @response.body.include?("e.preventDefault()")
    assert @response.body.include?("this.value.substring(0, start) + '  '")
    assert @response.body.include?("this.selectionStart = this.selectionEnd = start + 2")
    assert @response.body.include?("updatePreviewInstant()")
  end
  
  test "CSS includes proper styling for preview content" do
    sign_in @admin
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    
    # Should include styling for preview content elements
    style_selectors = [
      ".markup-preview .legal-section",
      ".markup-preview .legal-section h2",
      ".markup-preview .legal-section h3", 
      ".markup-preview .legal-section p",
      ".markup-preview .legal-section ul",
      ".markup-preview .legal-section li",
      ".markup-preview .loan-details",
      ".markup-preview .detail-row",
      ".markup-preview .contact-info"
    ]
    
    style_selectors.each do |selector|
      assert_select "style", text: /#{Regexp.escape(selector)}/, 
                   "Should include CSS for #{selector}"
    end
  end
  
  test "JavaScript error handling prevents crashes" do
    sign_in @admin
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    
    # Should include error handling checks
    assert @response.body.include?("if (!textarea || !preview)")
    assert @response.body.include?("return false")
    assert @response.body.include?("if (!text.trim())")
    assert @response.body.include?("if (!text) return ''")
    
    # Should handle edge cases gracefully
    assert @response.body.include?("sectionLines[0]?.trim()")
    assert @response.body.include?("|| []")
  end
  
  private
  
  def build_sample_content
    <<~CONTENT
      ## 1. Loan Agreement Details
      
      This is a test contract for live preview testing.
      
      **Loan Amount:** $500,000
      **Interest Rate:** 4.5%
      
      ### 1.1 Terms
      
      - Monthly payments required
      - **No penalty** for early repayment
      - Property insurance mandatory
      
      ## 2. Contact Information
      
      Lender: Test Lender
      Email: test@example.com
      Phone: 1-800-TEST
    CONTENT
  end
end