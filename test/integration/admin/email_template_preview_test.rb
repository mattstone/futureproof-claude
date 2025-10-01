require "test_helper"

class Admin::EmailTemplatePreviewTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:admin_user)
    sign_in @admin_user
  end

  test "email template preview shows single header with tagline" do
    template = EmailTemplate.find_by(template_type: 'verification') || EmailTemplate.create!(
      name: 'Test Verification',
      template_type: 'verification',
      email_category: 'operational',
      subject: 'Test Subject',
      content: '<p>Test content</p>'
    )

    get preview_admin_email_template_path(template)
    
    assert_response :success
    
    # Should have the tagline in header
    assert_select "body", text: /Your Financial Future, Secured/
    
    # Should have only one main branding H1 header
    h1_count = css_select("h1").select { |node| node.text.include?("Futureproof") }.count
    assert h1_count <= 1, "Should have at most one H1 with Futureproof branding, found #{h1_count}"
  end
end
