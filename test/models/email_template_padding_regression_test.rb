require "test_helper"

class EmailTemplatePaddingRegressionTest < ActiveSupport::TestCase
  test "security notification template must have proper padding in sign-in details section" do
    # Test case 1: Template with zero padding should fail validation
    template_with_zero_padding = EmailTemplate.new(
      name: "Security Alert - Bad Padding",
      template_type: "security_notification",
      subject: "Security Alert",
      content: <<~HTML
        <div>
          <h1>Security Alert</h1>
          <table>
            <tr>
              <td style="padding: 0;">
                <h3>Sign-in Details</h3>
                <div>
                  <strong>Time:</strong> {{security.sign_in_time}}<br>
                  <strong>IP Address:</strong> {{security.ip_address}}<br>
                  <strong>Browser:</strong> {{security.browser_info}}
                </div>
              </td>
            </tr>
          </table>
        </div>
      HTML
    )
    
    assert_not template_with_zero_padding.valid?
    assert_includes template_with_zero_padding.errors[:content].join, "must have proper padding"
  end

  test "security notification template with proper padding should pass validation" do
    # Test case 2: Template with proper padding should pass validation
    template_with_proper_padding = EmailTemplate.new(
      name: "Security Alert - Good Padding",
      template_type: "security_notification", 
      subject: "Security Alert",
      content: <<~HTML
        <div>
          <h1>Security Alert</h1>
          <table>
            <tr>
              <td style="padding: 20px 24px;">
                <h3>Sign-in Details</h3>
                <div>
                  <strong>Time:</strong> {{security.sign_in_time}}<br>
                  <strong>IP Address:</strong> {{security.ip_address}}<br>
                  <strong>Browser:</strong> {{security.browser_info}}
                </div>
              </td>
            </tr>
          </table>
        </div>
      HTML
    )
    
    assert template_with_proper_padding.valid?, template_with_proper_padding.errors.full_messages.join(", ")
  end

  test "non-security templates are not affected by padding validation" do
    # Test case 3: Other template types should not be affected by this validation
    verification_template = EmailTemplate.new(
      name: "Verification Email",
      template_type: "verification",
      subject: "Verify Account",
      content: '<div style="padding: 0;">Welcome! Your code is {{verification.verification_code}}</div>'
    )
    
    assert verification_template.valid?, verification_template.errors.full_messages.join(", ")
  end

  test "security templates without sign-in details are not affected" do
    # Test case 4: Security templates without sign-in details should pass
    simple_security_template = EmailTemplate.new(
      name: "Simple Security Alert", 
      template_type: "security_notification",
      subject: "Security Alert",
      content: '<div>Your account was accessed by {{user.first_name}}</div>'
    )
    
    assert simple_security_template.valid?, simple_security_template.errors.full_messages.join(", ")
  end

  test "existing security notification template in database has proper padding" do
    # Test case 5: Verify the actual security notification template has proper padding
    template = EmailTemplate.for_type('security_notification')
    
    assert template.present?, "Security notification template should exist"
    assert template.valid?, "Security notification template should be valid: #{template.errors.full_messages.join(', ')}"
    assert_includes template.content, 'padding: 20px 24px', "Template should contain proper padding"
  end

  test "attempting to update security template to remove padding should fail" do
    # Test case 6: Ensure we can't accidentally remove padding from existing template
    template = EmailTemplate.for_type('security_notification')
    original_content = template.content
    
    # Try to update with zero padding - this should fail
    bad_content = original_content.gsub('padding: 20px 24px', 'padding: 0')
    template.content = bad_content
    
    assert_not template.valid?
    assert_includes template.errors[:content].join, "must have proper padding"
    
    # Restore original content
    template.content = original_content
    assert template.valid?
  end
end